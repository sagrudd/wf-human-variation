process runBoundedStrTask {
    label "wf_human_str"
    tag "${entry.sample_id}:${entry.reference_id}:${entry.task_key}"

    cpus { entry.str_options.threads }
    memory 4.GB

    input:
        val entry
        val contract_json
        path haplotagged_contig_manifest
        path reference
        path reference_index
        path repeat_bed
        path variant_catalogue

    output:
        path "str.vcf.gz", emit: str_vcf
        path "str.vcf.gz.tbi", emit: str_vcf_index
        path "str-loci.tsv", emit: str_loci_tsv
        path "straglr.tsv", emit: straglr_tsv
        path "stranger.tsv", emit: stranger_tsv
        path "str-content-all.csv", emit: str_content_csv
        path "str_manifest.json", emit: str_manifest
        path "str_provenance.json", emit: str_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-str-contract.json <<'JSON'
${contract_json}
JSON

    export REFERENCE_FASTA="${reference}"
    export HAPLOTAGGED_CONTIG_MANIFEST="${haplotagged_contig_manifest}"
    export REPEAT_BED="${repeat_bed}"
    export VARIANT_CATALOGUE="${variant_catalogue}"
    python3 - <<'PY'
import json
import os
import shlex
from pathlib import Path

contract = json.loads(Path("bounded-str-contract.json").read_text())
manifest_path = Path(os.environ["HAPLOTAGGED_CONTIG_MANIFEST"])
manifest = json.loads(manifest_path.read_text())
if isinstance(manifest, dict):
    contigs = manifest.get("contigs", manifest.get("haplotagged_contig_bams", []))
else:
    contigs = manifest
if not isinstance(contigs, list) or not contigs:
    raise ValueError("haplotagged contig manifest must contain a non-empty contig list")

sex = "male" if contract["sex"] == "XY" else "female"
options = contract["str_options"]
reference_fasta = shlex.quote(os.environ["REFERENCE_FASTA"])
repeat_bed = shlex.quote(os.environ["REPEAT_BED"])
variant_catalogue = shlex.quote(os.environ["VARIANT_CATALOGUE"])
commands = []
for item in contigs:
    contig = str(item.get("contig", item.get("sq", ""))).strip()
    xam = str(item.get("xam", item.get("bam", ""))).strip()
    if not contig or not xam:
        raise ValueError("each haplotagged contig entry requires contig/sq and xam/bam")
    prefix = contig.replace("/", "_").replace(" ", "_")
    commands.extend([
        f"{{ grep {shlex.quote(contig)} -Fw {repeat_bed} || true; }} > {shlex.quote(prefix)}.repeats.bed",
        f"if [[ -s {shlex.quote(prefix)}.repeats.bed ]]; then",
        " ".join([
            "straglr-genotype",
            "--loci", shlex.quote(f"{prefix}.repeats.bed"),
            "--sample", shlex.quote(contract["sample_id"]),
            "--tsv", shlex.quote(f"{prefix}_straglr.tsv"),
            "-v", shlex.quote(f"{prefix}_tmp.vcf"),
            "--sex", sex,
            "--min_support", str(options["min_support"]),
            "--threads", str(options["threads"]),
            "--min_cluster_size", str(options["min_cluster_size"]),
            shlex.quote(xam),
            reference_fasta,
        ]),
        f"bgzip -c {shlex.quote(prefix)}_tmp.vcf > {shlex.quote(prefix)}_straglr.vcf.gz",
        f"tabix -p vcf {shlex.quote(prefix)}_straglr.vcf.gz",
        f"stranger -f {variant_catalogue} {shlex.quote(prefix)}_straglr.vcf.gz | sed 's/\\\\ /_/g' | bgzip -c > {shlex.quote(prefix)}_repeat-expansion_annotated.vcf.gz",
        f"tabix -p vcf {shlex.quote(prefix)}_repeat-expansion_annotated.vcf.gz",
        f"SnpSift extractFields {shlex.quote(prefix)}_repeat-expansion_annotated.vcf.gz CHROM POS ALT FILTER REF RL RU REPID VARID STR_STATUS > {shlex.quote(prefix)}_repeat-expansion_annotated.tsv",
        f"SnpSift extractFields {shlex.quote(prefix)}_repeat-expansion_annotated.vcf.gz CHROM POS DisplayRU STR_NORMAL_MAX STR_PATHOLOGIC_MIN VARID Disease > {shlex.quote(prefix)}_repeat-expansion_str-loci.tsv",
        f"samtools view -b -h --write-index -o {shlex.quote(prefix)}.wf_str_regions.bam##idx##{shlex.quote(prefix)}.wf_str_regions.bam.bai -L {shlex.quote(prefix)}.repeats.bed {shlex.quote(xam)}",
        f"tail -n +3 {shlex.quote(prefix)}_straglr.tsv | cut -f6 > {shlex.quote(prefix)}.reads_to_filter.txt",
        f"samtools view --write-index -N {shlex.quote(prefix)}.reads_to_filter.txt -o {shlex.quote(prefix)}.wf_str_reads.bam##idx##{shlex.quote(prefix)}.wf_str_reads.bam.bai {shlex.quote(prefix)}.wf_str_regions.bam",
        " ".join([
            "workflow-glue", "generate_str_content",
            "--straglr", shlex.quote(f"{prefix}_straglr.tsv"),
            "--stranger", shlex.quote(f"{prefix}_repeat-expansion_str-loci.tsv"),
            "--chr", shlex.quote(contig),
            "--repeat_bed", shlex.quote(f"{prefix}.repeats.bed"),
            "--str_reads_bam", shlex.quote(f"{prefix}.wf_str_reads.bam"),
        ]),
        f"printf '%s\\n' {shlex.quote(prefix)}_repeat-expansion_annotated.vcf.gz >> annotated-vcfs.txt",
        f"printf '%s\\n' {shlex.quote(prefix)}_repeat-expansion_str-loci.tsv >> str-loci-files.txt",
        f"printf '%s\\n' {shlex.quote(prefix)}_straglr.tsv >> straglr-files.txt",
        f"printf '%s\\n' {shlex.quote(prefix)}_repeat-expansion_annotated.tsv >> stranger-files.txt",
        f"printf '%s\\n' {shlex.quote(prefix)}_str-content.csv >> str-content-files.txt",
        "fi",
    ])

Path("run-str-contigs.sh").write_text("\\n".join(commands) + "\\n")
Path("str-contig-inputs.json").write_text(json.dumps(contigs, indent=2, sort_keys=True) + "\\n")
PY

    bash run-str-contigs.sh
    if [[ ! -s annotated-vcfs.txt ]]; then
        echo "No STR loci were present in the supplied haplotagged contigs." >&2
        exit 1
    fi

    if [[ "\$(wc -l < annotated-vcfs.txt | tr -d ' ')" = "1" ]]; then
        cp "\$(cat annotated-vcfs.txt)" str.vcf.gz
    else
        bcftools concat -a -O z -o str.vcf.gz \$(cat annotated-vcfs.txt)
    fi
    tabix -f -p vcf str.vcf.gz
    awk 'NR == 1 || FNR > 1' \$(cat str-loci-files.txt) > str-loci.tsv
    awk 'NR == 2 || FNR > 2' \$(cat straglr-files.txt) > straglr.tsv
    awk 'NR == 1 || FNR > 1' \$(cat stranger-files.txt) > stranger.tsv
    awk 'NR == 1 || FNR > 1' \$(cat str-content-files.txt) > str-content-all.csv

    python3 - <<'PY'
import datetime
import json
import shutil
from pathlib import Path

contract = json.loads(Path("bounded-str-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
contigs = json.loads(Path("str-contig-inputs.json").read_text())

manifest = {
    "schema": "wf-human-variation.str_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "sex": contract["sex"],
    "haplotagged_contig_manifest": contract["haplotagged_contig_manifest"],
    "haplotagged_contig_digest": contract["haplotagged_contig_digest"],
    "str_config_digest": contract["str_config_digest"],
    "container_digest": contract["container_digest"],
    "contig_count": len(contigs),
    "outputs": {
        "str_vcf": str(output_paths["str_vcf"]),
        "str_vcf_index": str(output_paths["str_vcf_index"]),
        "str_loci_tsv": str(output_paths["str_loci_tsv"]),
        "straglr_tsv": str(output_paths["straglr_tsv"]),
        "stranger_tsv": str(output_paths["stranger_tsv"]),
        "str_content_csv": str(output_paths["str_content_csv"]),
    },
    "optional_products": {
        "html_report": {"requested": False, "available": False, "reason": "removed_from_humvar3_contract"},
    },
}
Path("str_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.str_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "tools": ["straglr-genotype", "stranger", "SnpSift", "samtools", "bcftools", "workflow-glue generate_str_content"],
    "container_digest": contract["container_digest"],
    "command_files": ["run-str-contigs.sh"],
    "input_checksums": {
        "haplotagged_contigs": contract["haplotagged_contig_digest"],
        "str_config": contract["str_config_digest"],
    },
}
Path("str_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.str_qc.v1",
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "task_key": contract["task_key"],
    "sex": contract["sex"],
    "contig_count": len(contigs),
    "str_vcf": str(output_paths["str_vcf"]),
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

copies = {
    "str_vcf": Path("str.vcf.gz"),
    "str_vcf_index": Path("str.vcf.gz.tbi"),
    "str_loci_tsv": Path("str-loci.tsv"),
    "straglr_tsv": Path("straglr.tsv"),
    "stranger_tsv": Path("stranger.tsv"),
    "str_content_csv": Path("str-content-all.csv"),
    "str_manifest": Path("str_manifest.json"),
    "str_provenance": Path("str_provenance.json"),
    "qc_stats": Path("qc_stats.json"),
}
for kind, source in copies.items():
    target = output_paths[kind]
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)

marker_path = Path(contract["completion_marker_path"])
marker_path.parent.mkdir(parents=True, exist_ok=True)
marker = {
    "marker_schema": "gnostikon.task_completion.v1",
    "task_key": contract["task_key"],
    "task_family": contract["task_family"],
    "status": "succeeded",
    "completed_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
    "outputs": [
        {"kind": kind, "path": str(output_paths[kind]), "required": True}
        for kind in sorted(output_paths)
    ],
    "metadata": {
        "bounded_entry": contract["entry_name"],
        "entry_schema": contract["entry_schema"],
        "sample_id": contract["sample_id"],
        "reference_id": contract["reference_id"],
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
