process runBoundedTrioMergeSortTask {
    label "clair3nova"
    tag "${entry.family_id}:${entry.analysis_intent_id}:${entry.reference_id}:${entry.role}:${entry.sample_id}:${entry.task_key}"

    cpus 2
    memory { 8.GB * task.attempt }
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }
    maxRetries 3

    input:
        val entry
        val contract_json
        path trio_denovo_vcf_fragments
        path trio_candidate_beds
        path snp_vcf
        path snp_vcf_index
        path snp_gvcf
        path snp_gvcf_index
        path reference
        path reference_index

    output:
        path "trio_snp.vcf.gz", emit: trio_snp_vcf
        path "trio_snp.vcf.gz.tbi", emit: trio_snp_vcf_index
        path "trio_snp.gvcf.gz", emit: trio_snp_gvcf
        path "trio_snp.gvcf.gz.tbi", emit: trio_snp_gvcf_index
        path "trio_merge_manifest.json", emit: trio_merge_manifest
        path "trio_merge_command.json", emit: trio_merge_command_json
        path "family_provenance.json", emit: family_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-family-germline-snp-merge-contract.json <<'JSON'
${contract_json}
JSON

    export TRIO_DENOVO_VCF_FRAGMENTS="${trio_denovo_vcf_fragments}"
    export TRIO_CANDIDATE_BEDS="${trio_candidate_beds}"
    export SNP_VCF="${snp_vcf}"
    export SNP_GVCF="${snp_gvcf}"
    export REFERENCE_FASTA="${reference}"

    python3 - <<'PY'
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


def safe_component(value):
    text = str(value).strip()
    return re.sub(r"[^A-Za-z0-9_.-]+", "-", text).strip("-") or "unknown"


def run_command(cmd, commands):
    commands.append(cmd)
    return subprocess.run(cmd, check=False)


def copy_output(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


contract = json.loads(Path("bounded-family-germline-snp-merge-contract.json").read_text())
options = contract["family_germline_merge_options"]
contigs = [str(contig) for contig in options["contigs"]]
sample_id = contract["sample_id"]
role = contract["role"]
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}

clair3_nova_path = os.environ.get("CLAIR3_NOVA_PATH", "").strip()
if not clair3_nova_path:
    raise EnvironmentError("CLAIR3_NOVA_PATH must be set by the Clair3-Nova container")
clair3_nova_script = str(Path(clair3_nova_path) / "clair3.py")

tmp = Path("tmp")
tmp.mkdir(exist_ok=True)
(tmp / "CONTIGS").write_text("\\n".join(contigs) + "\\n")

calls_dir = Path("calls")
calls_dir.mkdir(exist_ok=True)
fragment_root = Path(os.environ["TRIO_DENOVO_VCF_FRAGMENTS"])
role_fragment_root = fragment_root / role
source_fragment_root = role_fragment_root if role_fragment_root.exists() else fragment_root
fragment_files = sorted(path for path in source_fragment_root.rglob("*.vcf") if path.is_file())
for fragment in fragment_files:
    shutil.copy2(fragment, calls_dir / fragment.name)

commands = []
failure = None
status = "completed"
if not fragment_files:
    failure = {"stage": "collect_denovo_fragments", "reason": "no_denovo_fragments"}
else:
    sorted_trio_cmd = [
        "pypy",
        clair3_nova_script,
        "SortVcf_Trio",
        "--input_dir",
        "calls",
        "--vcf_fn_prefix",
        "trio",
        "--output_fn",
        f"{sample_id}_c3t.vcf",
        "--sampleName",
        sample_id,
        "--ref_fn",
        os.environ["REFERENCE_FASTA"],
        "--tmp_path",
        "tmp",
        "--contigs_fn",
        "tmp/CONTIGS",
    ]
    result = run_command(sorted_trio_cmd, commands)
    if result.returncode != 0:
        failure = {"stage": "sort_denovo_fragments", "exit_code": result.returncode}

if failure is None:
    Path("merged_calls").mkdir(exist_ok=True)
    Path("merged_gvcf_calls").mkdir(exist_ok=True)
    for contig in contigs:
        merge_cmd = [
            "pypy",
            clair3_nova_script,
            "MergeVcf_Trio",
            "--pileup_vcf_fn",
            os.environ["SNP_VCF"],
            "--trio_vcf_fn",
            f"{sample_id}_c3t.vcf.gz",
            "--output_fn",
            f"merged_calls/merge_{safe_component(contig)}.vcf",
            "--gvcf_fn",
            f"merge_{safe_component(contig)}.gvcf.lz4",
            "--platform",
            options["platform"],
            "--print_ref_calls",
            str(bool(options["print_ref_calls"])),
            "--gvcf",
            str(bool(options["gvcf"])),
            "--bed_fn_prefix",
            os.environ["TRIO_CANDIDATE_BEDS"],
            "--haploid_precise",
            str(bool(options["haploid_precise"])),
            "--haploid_sensitive",
            str(bool(options["haploid_sensitive"])),
            "--non_var_gvcf_fn",
            os.environ["SNP_GVCF"],
            "--ref_fn",
            os.environ["REFERENCE_FASTA"],
            "--ctgName",
            contig,
        ]
        result = run_command(merge_cmd, commands)
        if result.returncode != 0:
            failure = {"stage": "merge_trio_vcf", "contig": contig, "exit_code": result.returncode}
            break
        lz4_cmd = [
            "lz4",
            f"merge_{safe_component(contig)}.gvcf.lz4",
            f"merged_gvcf_calls/merge_{safe_component(contig)}.gvcf",
        ]
        result = run_command(lz4_cmd, commands)
        if result.returncode != 0:
            failure = {"stage": "decompress_trio_gvcf", "contig": contig, "exit_code": result.returncode}
            break

if failure is None:
    sort_vcf_cmd = [
        "pypy",
        clair3_nova_script,
        "SortVcf_Trio",
        "--input_dir",
        "merged_calls",
        "--vcf_fn_prefix",
        "merge",
        "--output_fn",
        "unfiltered.vcf",
        "--sampleName",
        sample_id,
        "--ref_fn",
        os.environ["REFERENCE_FASTA"],
        "--tmp_path",
        "tmp",
        "--contigs_fn",
        "tmp/CONTIGS",
    ]
    result = run_command(sort_vcf_cmd, commands)
    if result.returncode != 0:
        failure = {"stage": "sort_merged_vcf", "exit_code": result.returncode}

if failure is None:
    filtered_vcf_cmd = ["bash", "-c", "bcftools view --exclude 'FILTER==\"RefCall\"' unfiltered.vcf.gz | bgzip > trio_snp.pre_dnp.vcf.gz"]
    result = run_command(filtered_vcf_cmd, commands)
    if result.returncode != 0:
        failure = {"stage": "filter_ref_calls", "exit_code": result.returncode}

if failure is None:
    index_pre_dnp_cmd = ["tabix", "-p", "vcf", "trio_snp.pre_dnp.vcf.gz"]
    result = run_command(index_pre_dnp_cmd, commands)
    if result.returncode != 0:
        failure = {"stage": "index_pre_dnp_vcf", "exit_code": result.returncode}

if failure is None:
    sort_gvcf_cmd = [
        "pypy",
        clair3_nova_script,
        "SortVcf_Trio",
        "--input_dir",
        "merged_gvcf_calls",
        "--vcf_fn_suffix",
        ".gvcf",
        "--output_fn",
        "trio_snp.pre_dnp.gvcf",
        "--sampleName",
        sample_id,
        "--ref_fn",
        os.environ["REFERENCE_FASTA"],
        "--tmp_path",
        "tmp",
        "--contigs_fn",
        "tmp/CONTIGS",
    ]
    result = run_command(sort_gvcf_cmd, commands)
    if result.returncode != 0:
        failure = {"stage": "sort_merged_gvcf", "exit_code": result.returncode}

if failure is None:
    for extension in ("vcf", "gvcf"):
        source = f"trio_snp.pre_dnp.{extension}.gz"
        final = f"trio_snp.{extension}.gz"
        dnp_query_cmd = ["bash", "-c", f"bcftools query -f '%CHROM\\\\t%POS\\\\t%INFO/DNP\\\\n' {source} | bgzip -c > dnp_info.{extension}.tsv.gz"]
        result = run_command(dnp_query_cmd, commands)
        if result.returncode != 0:
            failure = {"stage": "extract_dnp", "extension": extension, "exit_code": result.returncode}
            break
        index_dnp_cmd = ["tabix", "--sequence", "1", "--begin", "2", "--end", "2", f"dnp_info.{extension}.tsv.gz"]
        result = run_command(index_dnp_cmd, commands)
        if result.returncode != 0:
            failure = {"stage": "index_dnp_table", "extension": extension, "exit_code": result.returncode}
            break
        Path(f"header.{extension}.txt").write_text('##FORMAT=<ID=DNP,Number=.,Type=Float,Description="de novo variant probability">\\n')
        annotate_cmd = [
            "bcftools",
            "annotate",
            "-x",
            "INFO/DNP",
            "--header-lines",
            f"header.{extension}.txt",
            "--annotations",
            f"dnp_info.{extension}.tsv.gz",
            "--columns",
            "CHROM,POS,FORMAT/DNP",
            "-o",
            f"trio_snp.edit.{extension}.vcf",
            source,
        ]
        result = run_command(annotate_cmd, commands)
        if result.returncode != 0:
            failure = {"stage": "annotate_dnp", "extension": extension, "exit_code": result.returncode}
            break
        compress_cmd = ["bash", "-c", f"bgzip -c trio_snp.edit.{extension}.vcf > {final}"]
        result = run_command(compress_cmd, commands)
        if result.returncode != 0:
            failure = {"stage": "compress_dnp_output", "extension": extension, "exit_code": result.returncode}
            break
        index_cmd = ["tabix", "--preset", "vcf", final]
        result = run_command(index_cmd, commands)
        if result.returncode != 0:
            failure = {"stage": "index_dnp_output", "extension": extension, "exit_code": result.returncode}
            break

if failure is not None:
    status = "failed"

Path("trio_merge_command.json").write_text(json.dumps(commands, indent=2, sort_keys=True) + "\\n")
manifest = {
    "schema": "wf-human-variation.trio_merge_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
    "role": role,
    "sample_id": sample_id,
    "contigs": contigs,
    "state": status,
    "failure": failure,
    "fragment_file_count": len(fragment_files),
    "trio_denovo_vcf_fragments_digest": contract["trio_denovo_vcf_fragments_digest"],
    "trio_candidate_beds_digest": contract["trio_candidate_beds_digest"],
    "clair3_nova_model_digest": contract["clair3_nova_model_digest"],
    "family_germline_config_digest": contract["family_germline_config_digest"],
    "container_digest": contract["container_digest"],
    "outputs": {
        "trio_snp_vcf": str(output_paths["trio_snp_vcf"]),
        "trio_snp_vcf_index": str(output_paths["trio_snp_vcf_index"]),
        "trio_snp_gvcf": str(output_paths["trio_snp_gvcf"]),
        "trio_snp_gvcf_index": str(output_paths["trio_snp_gvcf_index"]),
        "trio_merge_manifest": str(output_paths["trio_merge_manifest"]),
        "trio_merge_command_json": str(output_paths["trio_merge_command_json"]),
    },
}
Path("trio_merge_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.family_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "tool": "clair3-nova",
    "tool_operations": [
        "SortVcf_Trio",
        "MergeVcf_Trio",
        "lz4",
        "bcftools view",
        "bcftools annotate",
        "bgzip",
        "tabix",
    ],
    "container_digest": contract["container_digest"],
    "command_arguments": commands,
    "input_checksums": {
        "trio_denovo_vcf_fragments": contract["trio_denovo_vcf_fragments_digest"],
        "trio_candidate_beds": contract["trio_candidate_beds_digest"],
        "snp_vcf": contract["snp_vcf_digest"],
        "snp_vcf_index": contract["snp_vcf_index_digest"],
        "snp_gvcf": contract["snp_gvcf_digest"],
        "snp_gvcf_index": contract["snp_gvcf_index_digest"],
        "family_germline_config": contract["family_germline_config_digest"],
    },
    "model_checksums": {
        "clair3_nova_model": contract["clair3_nova_model_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
}
Path("family_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.trio_merge_qc.v1",
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "task_key": contract["task_key"],
    "role": role,
    "sample_id": sample_id,
    "state": status,
    "contig_count": len(contigs),
    "fragment_file_count": len(fragment_files),
    "failure": failure,
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

if failure is not None:
    for kind, source in {
        "trio_merge_manifest": Path("trio_merge_manifest.json"),
        "trio_merge_command_json": Path("trio_merge_command.json"),
        "family_provenance": Path("family_provenance.json"),
        "qc_stats": Path("qc_stats.json"),
    }.items():
        copy_output(source, output_paths[kind])
    sys.exit(1)

copies = {
    "trio_snp_vcf": Path("trio_snp.vcf.gz"),
    "trio_snp_vcf_index": Path("trio_snp.vcf.gz.tbi"),
    "trio_snp_gvcf": Path("trio_snp.gvcf.gz"),
    "trio_snp_gvcf_index": Path("trio_snp.gvcf.gz.tbi"),
    "trio_merge_manifest": Path("trio_merge_manifest.json"),
    "trio_merge_command_json": Path("trio_merge_command.json"),
    "family_provenance": Path("family_provenance.json"),
    "qc_stats": Path("qc_stats.json"),
}
for kind, source in copies.items():
    copy_output(source, output_paths[kind])

marker_path = Path(contract["completion_marker_path"])
marker_path.parent.mkdir(parents=True, exist_ok=True)
marker = {
    "marker_schema": "gnostikon.task_completion.v1",
    "task_key": contract["task_key"],
    "task_family": contract["task_family"],
    "status": "succeeded",
    "completed_at_utc": utc_now(),
    "outputs": [
        {"kind": kind, "path": str(output_paths[kind]), "required": True}
        for kind in sorted(output_paths)
    ],
    "metadata": {
        "bounded_entry": contract["entry_name"],
        "entry_schema": contract["entry_schema"],
        "family_id": contract["family_id"],
        "analysis_intent_id": contract["analysis_intent_id"],
        "reference_id": contract["reference_id"],
        "role": role,
        "sample_id": sample_id,
        "state": status,
        "contig_count": len(contigs),
        "fragment_file_count": len(fragment_files),
    },
}
tmp_marker = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp_marker.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp_marker.replace(marker_path)
PY
    """
}
