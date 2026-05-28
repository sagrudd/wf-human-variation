process runBoundedSomaticGermlineHelperTask {
    label "wf_human_snp"
    tag "${entry.analysis_intent_id}:${entry.helper_role}:${entry.helper_sample_id}:${entry.task_key}"

    cpus { entry.variant_options.threads }
    memory { (32.GB * task.attempt) - 1.GB }
    maxRetries 1
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }

    input:
        val entry
        val contract_json
        path helper_aggregate_xam
        path helper_aggregate_xam_index
        path reference
        path reference_index
        path clair3_model

    output:
        path "germline_helper.vcf.gz", emit: germline_helper_vcf
        path "germline_helper.vcf.gz.tbi", emit: germline_helper_vcf_index
        path "germline_helper_manifest.json", emit: germline_helper_manifest
        path "germline_helper_command.json", emit: germline_helper_command_json
        path "germline_helper.log", emit: germline_helper_logs
        path "somatic_provenance.json", emit: somatic_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-somatic-germline-helper-contract.json <<'JSON'
${contract_json}
JSON

    export HELPER_XAM="${helper_aggregate_xam}"
    export REFERENCE_FASTA="${reference}"
    export CLAIR3_MODEL="${clair3_model}"
    python3 - <<'PY'
import json
import os
import shlex
from pathlib import Path

contract = json.loads(Path("bounded-somatic-germline-helper-contract.json").read_text())
options = contract["variant_options"]
snp_min_af = "0.0" if options["genotyping_vcf"] else str(options["snp_min_af"])
indel_min_af = "0.0" if options["genotyping_vcf"] else str(options["indel_min_af"])
cmd = [
    "run_clair3.sh",
    "--bam_fn", os.environ["HELPER_XAM"],
    "--ref_fn", os.environ["REFERENCE_FASTA"],
    "--output", "clair3_helper_output",
    "--platform", "ont",
    "--sample_name", contract["helper_sample_id"],
    "--model_path", os.environ["CLAIR3_MODEL"],
    "--threads", str(options["threads"]),
    "--chunk_num", str(options["chunk_num"]),
    "--chunk_size", str(options["chunk_size"]),
    "--qual", str(options["min_qual"]),
    "--var_pct_full", str(options["var_pct_full"]),
    "--ref_pct_full", str(options["ref_pct_full"]),
    "--snp_min_af", snp_min_af,
    "--indel_min_af", indel_min_af,
    "--min_contig_size", str(options["min_contig_size"]),
    "--include_all_ctgs", str(options["include_all_ctgs"]).lower(),
]
if options["ctg_name"]:
    cmd.extend(["--ctg_name", options["ctg_name"]])
if options["target_bed"]:
    cmd.extend(["--bed_fn", options["target_bed"]])
if options["genotyping_vcf"]:
    cmd.extend(["--vcf_fn", options["genotyping_vcf"]])

command_metadata = {
    "schema": "wf-human-variation.somatic_germline_helper_command.v1",
    "task_key": contract["task_key"],
    "tool": "clair3",
    "stage": "germline_helper_calling",
    "run_clair3": cmd,
    "structured_options": options,
    "helper_role": contract["helper_role"],
    "helper_state": "computed",
}
Path("germline_helper_command.json").write_text(json.dumps(command_metadata, indent=2, sort_keys=True) + "\\n")
Path("run-clair3-germline-helper.command.sh").write_text(" ".join(shlex.quote(part) for part in cmd) + "\\n")
PY

    bash run-clair3-germline-helper.command.sh > germline_helper.log 2>&1

    python3 - <<'PY'
import datetime
import json
import shutil
from pathlib import Path


def copy_output(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


contract = json.loads(Path("bounded-somatic-germline-helper-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
command_metadata = json.loads(Path("germline_helper_command.json").read_text())

vcf_source = Path("clair3_helper_output/merge_output.vcf.gz")
vcf_index_source = Path("clair3_helper_output/merge_output.vcf.gz.tbi")
if not vcf_source.exists() or not vcf_index_source.exists():
    raise FileNotFoundError("Clair3 did not produce merge_output.vcf.gz and index")

shutil.copy2(vcf_source, "germline_helper.vcf.gz")
shutil.copy2(vcf_index_source, "germline_helper.vcf.gz.tbi")

normal_vcf_state = {
    "state": "ready",
    "mode": "computed",
    "caller_name": "Clair3",
    "source_name": "somatic_germline_helper",
    "helper_role": contract["helper_role"],
    "helper_sample_id": contract["helper_sample_id"],
    "sample_id": contract["helper_sample_id"],
    "reference_id": contract["reference_id"],
    "vcf_path": str(output_paths["germline_helper_vcf"]),
    "index_path": str(output_paths["germline_helper_vcf_index"]),
}
manifest = {
    "schema": "wf-human-variation.somatic_germline_helper_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "helper_role": contract["helper_role"],
    "helper_sample_id": contract["helper_sample_id"],
    "reference_id": contract["reference_id"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
    "helper_aggregate_xam": contract["helper_aggregate_xam"],
    "helper_aggregate_xam_digest": contract["helper_aggregate_xam_digest"],
    "clair3_model": contract["clair3_model"],
    "clair3_model_name": contract["clair3_model_name"] or Path(contract["clair3_model"]).name,
    "clair3_model_digest": contract["clair3_model_digest"],
    "clair3_model_table_digest": contract["clair3_model_table_digest"],
    "germline_helper_config_digest": contract["germline_helper_config_digest"],
    "container_digest": contract["container_digest"],
    "normal_vcf_state": normal_vcf_state,
    "outputs": {key: str(value) for key, value in output_paths.items()},
}
Path("germline_helper_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.somatic_provenance.v1",
    "task_family": contract["task_family"],
    "task_stage": "germline_helper_calling",
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "tool": "clair3",
    "container_digest": contract["container_digest"],
    "command_arguments": command_metadata,
    "input_checksums": {
        "helper_aggregate_xam": contract["helper_aggregate_xam_digest"],
        "helper_aggregate_xam_index": contract["helper_aggregate_xam_index_digest"],
        "reference": contract["reference_digest"],
        "clair3_model": contract["clair3_model_digest"],
        "clair3_model_table": contract["clair3_model_table_digest"],
        "germline_helper_config": contract["germline_helper_config_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
}
Path("somatic_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.somatic_germline_helper_qc.v1",
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "helper_role": contract["helper_role"],
    "helper_sample_id": contract["helper_sample_id"],
    "reference_id": contract["reference_id"],
    "normal_vcf_state": normal_vcf_state,
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

for kind, source in {
    "germline_helper_vcf": Path("germline_helper.vcf.gz"),
    "germline_helper_vcf_index": Path("germline_helper.vcf.gz.tbi"),
    "germline_helper_manifest": Path("germline_helper_manifest.json"),
    "germline_helper_command_json": Path("germline_helper_command.json"),
    "germline_helper_logs": Path("germline_helper.log"),
    "somatic_provenance": Path("somatic_provenance.json"),
    "qc_stats": Path("qc_stats.json"),
}.items():
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
        "analysis_intent_id": contract["analysis_intent_id"],
        "pair_id": contract["pair_id"],
        "helper_role": contract["helper_role"],
        "helper_sample_id": contract["helper_sample_id"],
        "reference_id": contract["reference_id"],
        "germline_helper_state": "computed",
        "normal_vcf_state": normal_vcf_state,
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
