process runBoundedSpectreCnvTask {
    label "spectre"
    tag "${entry.sample_id}:${entry.reference_id}:${entry.cnv_mode}:${entry.task_key}"

    cpus { entry.cnv_options.threads }
    memory 8.GB

    input:
        val entry
        val contract_json
        path aggregate_xam
        path aggregate_xam_index
        path reference
        path reference_index
        path snp_vcf
        path snp_vcf_index
        path mosdepth_summary
        path mosdepth_regions
        path mosdepth_distribution
        path mosdepth_thresholds

    output:
        path "cnv.vcf.gz", emit: cnv_vcf
        path "cnv.vcf.gz.tbi", emit: cnv_vcf_index
        path "cnv.bed", emit: cnv_bed
        path "predicted_karyotype.txt", emit: cnv_karyotype
        path "cnv_manifest.json", emit: cnv_manifest
        path "cnv_provenance.json", emit: cnv_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-cnv-contract.json <<'JSON'
${contract_json}
JSON

    mkdir -p readstats spectre_output
    cp ${mosdepth_summary} readstats/
    cp ${mosdepth_regions} readstats/
    cp ${mosdepth_distribution} readstats/
    cp ${mosdepth_thresholds} readstats/

    export REFERENCE_FASTA="${reference}"
    export SNP_VCF="${snp_vcf}"
    python3 - <<'PY'
import json
import os
import shlex
from pathlib import Path

contract = json.loads(Path("bounded-cnv-contract.json").read_text())
options = contract["cnv_options"]
spectre_options = options.get("spectre_options", {})
cmd = [
    "spectre", "CNVCaller",
    "--bin-size", "1000",
    "--coverage", "readstats/",
    "--sample-id", contract["sample_id"],
    "--output-dir", "spectre_output/",
    "--reference", os.environ["REFERENCE_FASTA"],
    "--blacklist", f"{options['genome_build']}_blacklist_v1.0",
    "--snv", os.environ["SNP_VCF"],
    "--metadata", f"{options['genome_build']}_metadata",
]
if "min_cnv_len" in spectre_options:
    cmd.extend(["--min-cnv-len", str(int(spectre_options["min_cnv_len"]))])
Path("spectre.command.sh").write_text(" ".join(shlex.quote(part) for part in cmd) + "\\n")
Path("spectre.command.json").write_text(json.dumps(cmd, indent=2, sort_keys=True) + "\\n")
PY

    bash spectre.command.sh
    cp spectre_output/${entry.sample_id}_cnv.bed cnv.bed
    cp spectre_output/predicted_karyotype.txt predicted_karyotype.txt
    bgzip -c spectre_output/${entry.sample_id}.vcf > cnv.vcf.gz
    tabix -f -p vcf cnv.vcf.gz

    python3 - <<'PY'
import datetime
import json
import shutil
from pathlib import Path

contract = json.loads(Path("bounded-cnv-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
command = json.loads(Path("spectre.command.json").read_text())

manifest = {
    "schema": "wf-human-variation.cnv_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "cnv_mode": contract["cnv_mode"],
    "aggregate_xam": contract["aggregate_xam"],
    "aggregate_xam_digest": contract["aggregate_xam_digest"],
    "snp_vcf": contract["snp_vcf"],
    "snp_vcf_digest": contract["snp_vcf_digest"],
    "cnv_config_digest": contract["cnv_config_digest"],
    "container_digest": contract["container_digest"],
    "outputs": {
        "cnv_vcf": str(output_paths["cnv_vcf"]),
        "cnv_vcf_index": str(output_paths["cnv_vcf_index"]),
        "cnv_bed": str(output_paths["cnv_bed"]),
        "cnv_karyotype": str(output_paths["cnv_karyotype"]),
    },
    "optional_products": {
        "annotated_cnv_vcf": {"requested": False, "available": False, "reason": "deferred_bounded_mode"},
        "html_report": {"requested": False, "available": False, "reason": "removed_from_humvar3_contract"},
    },
}
Path("cnv_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.cnv_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "tool": "spectre",
    "container_digest": contract["container_digest"],
    "command_arguments": command,
    "input_checksums": {
        "aggregate_xam": contract["aggregate_xam_digest"],
        "snp_vcf": contract["snp_vcf_digest"],
        "cnv_config": contract["cnv_config_digest"],
    },
}
Path("cnv_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.cnv_qc.v1",
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "task_key": contract["task_key"],
    "cnv_mode": contract["cnv_mode"],
    "cnv_vcf": str(output_paths["cnv_vcf"]),
    "cnv_bed": str(output_paths["cnv_bed"]),
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

copies = {
    "cnv_vcf": Path("cnv.vcf.gz"),
    "cnv_vcf_index": Path("cnv.vcf.gz.tbi"),
    "cnv_bed": Path("cnv.bed"),
    "cnv_karyotype": Path("predicted_karyotype.txt"),
    "cnv_manifest": Path("cnv_manifest.json"),
    "cnv_provenance": Path("cnv_provenance.json"),
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
        "cnv_mode": contract["cnv_mode"],
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}

process runBoundedQdnaseqCnvTask {
    label "wf_cnv"
    tag "${entry.sample_id}:${entry.reference_id}:${entry.cnv_mode}:${entry.task_key}"

    cpus 1
    memory { 16.GB * task.attempt }
    maxRetries 1
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }

    input:
        val entry
        val contract_json
        path aggregate_xam
        path aggregate_xam_index
        path reference
        path reference_index

    output:
        path "cnv.vcf.gz", emit: cnv_vcf
        path "cnv.vcf.gz.tbi", emit: cnv_vcf_index
        path "cnv_segments.bed", emit: cnv_segments_bed
        path "cnv_segments.vcf", emit: cnv_segments_vcf
        path "cnv_manifest.json", emit: cnv_manifest
        path "cnv_provenance.json", emit: cnv_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-cnv-contract.json <<'JSON'
${contract_json}
JSON

    run_qdnaseq.r --bam ${aggregate_xam} --out_prefix cnv --binsize ${entry.cnv_options.qdnaseq_options.bin_size} --reference ${entry.cnv_options.genome_build}
    cut -f5 cnv_calls.bed | paste cnv_bins.bed - > cnv_segments.bed

    mv cnv_calls.vcf raw.vcf
    mv cnv_segs.vcf raw_segs.vcf
    fix_qdnaseq_vcf.py -i raw.vcf -o cnv.vcf --sample_id ${entry.sample_id}
    fix_qdnaseq_vcf.py -i raw_segs.vcf -o cnv_segments.vcf --sample_id ${entry.sample_id}

    bgzip -c cnv.vcf > cnv.vcf.gz
    tabix -f -p vcf cnv.vcf.gz

    python3 - <<'PY'
import datetime
import json
import shutil
from pathlib import Path

contract = json.loads(Path("bounded-cnv-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
command = [
    "run_qdnaseq.r",
    "--bam", contract["aggregate_xam"],
    "--out_prefix", "cnv",
    "--binsize", str(contract["cnv_options"]["qdnaseq_options"]["bin_size"]),
    "--reference", contract["cnv_options"]["genome_build"],
]

manifest = {
    "schema": "wf-human-variation.cnv_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "cnv_mode": contract["cnv_mode"],
    "aggregate_xam": contract["aggregate_xam"],
    "aggregate_xam_digest": contract["aggregate_xam_digest"],
    "cnv_config_digest": contract["cnv_config_digest"],
    "container_digest": contract["container_digest"],
    "outputs": {
        "cnv_vcf": str(output_paths["cnv_vcf"]),
        "cnv_vcf_index": str(output_paths["cnv_vcf_index"]),
        "cnv_segments_bed": str(output_paths["cnv_segments_bed"]),
        "cnv_segments_vcf": str(output_paths["cnv_segments_vcf"]),
    },
    "optional_products": {
        "html_report": {"requested": False, "available": False, "reason": "removed_from_humvar3_contract"},
    },
}
Path("cnv_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.cnv_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "tool": "qdnaseq",
    "container_digest": contract["container_digest"],
    "command_arguments": command,
    "input_checksums": {
        "aggregate_xam": contract["aggregate_xam_digest"],
        "cnv_config": contract["cnv_config_digest"],
    },
}
Path("cnv_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.cnv_qc.v1",
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "task_key": contract["task_key"],
    "cnv_mode": contract["cnv_mode"],
    "cnv_vcf": str(output_paths["cnv_vcf"]),
    "cnv_segments_bed": str(output_paths["cnv_segments_bed"]),
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

copies = {
    "cnv_vcf": Path("cnv.vcf.gz"),
    "cnv_vcf_index": Path("cnv.vcf.gz.tbi"),
    "cnv_segments_bed": Path("cnv_segments.bed"),
    "cnv_segments_vcf": Path("cnv_segments.vcf"),
    "cnv_manifest": Path("cnv_manifest.json"),
    "cnv_provenance": Path("cnv_provenance.json"),
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
        "cnv_mode": contract["cnv_mode"],
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
