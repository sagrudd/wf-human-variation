process runBoundedSomaticTumourOnlySnvTask {
    label "somatic_clairs_to"
    tag "${entry.analysis_intent_id}:${entry.sample_id}:${entry.reference_id}:${entry.task_key}"

    cpus { entry.clairs_to_options.threads }
    memory { 32.GB * task.attempt }
    maxRetries 1
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }

    input:
        val entry
        val contract_json
        path aggregate_xam
        path aggregate_xam_index
        path reference
        path reference_index
        path clairs_to_model
        path clairs_to_database_bundle

    output:
        path "${entry.sample_id}.wf-somatic-snv.vcf.gz", emit: somatic_snv_vcf
        path "${entry.sample_id}.wf-somatic-snv.vcf.gz.tbi", emit: somatic_snv_vcf_index
        path "somatic_tumour_only_snv_manifest.json", emit: somatic_tumour_only_snv_manifest
        path "somatic_tumour_only_snv_command.json", emit: somatic_tumour_only_snv_command_json
        path "somatic_tumour_only_snv.log", emit: somatic_tumour_only_snv_logs
        path "somatic_provenance.json", emit: somatic_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-somatic-tumour-only-snv-contract.json <<'JSON'
${contract_json}
JSON

    export AGGREGATE_XAM="${aggregate_xam}"
    export REFERENCE_FASTA="${reference}"
    export CLAIRS_TO_MODEL="${clairs_to_model}"
    export CLAIRS_TO_DATABASE_BUNDLE="${clairs_to_database_bundle}"
    python3 - <<'PY'
import json
import os
import shlex
import subprocess
from pathlib import Path


def assert_optional_path(contract, name):
    value = contract.get(name) or ""
    if value and not Path(value).exists():
        raise FileNotFoundError(f"{name} was declared but does not exist: {value}")
    return value


contract = json.loads(Path("bounded-somatic-tumour-only-snv-contract.json").read_text())
options = contract["clairs_to_options"]
candidate_vcf = assert_optional_path(contract, "candidate_vcf")
genotyping_vcf = assert_optional_path(contract, "genotyping_vcf")
if candidate_vcf and genotyping_vcf:
    raise ValueError("candidate_vcf and genotyping_vcf are mutually exclusive for ClairS-TO")
target_bed = assert_optional_path(contract, "target_bed")

model_path = Path(os.environ["CLAIRS_TO_MODEL"])
model_name = contract.get("clairs_to_model_name") or model_path.name
command = [
    "run_clairs_to",
    "--tumor_bam_fn", os.environ["AGGREGATE_XAM"],
    "--ref_fn", os.environ["REFERENCE_FASTA"],
    "--platform", model_name,
    "--output_dir", "clairs_to_output",
    "--threads", str(options["threads"]),
    "--snv_min_af", str(options["min_af"]),
    "--min_coverage", str(options["min_coverage"]),
    "--qual", str(options["qual"]),
    "--chunk_size", str(options["chunk_size"]),
]
if options["chunk_num"]:
    command.extend(["--chunk_num", str(options["chunk_num"])])
if options["ctg_name"]:
    command.extend(["--ctg_name", options["ctg_name"]])
if options["include_all_ctgs"]:
    command.append("--include_all_ctgs")
if options["include_germline"]:
    command.append("--include_germline")
if options["show_ref"]:
    command.append("--show_ref")
if options["debug"]:
    command.append("--debug")
command.extend(["--indel_min_af", str(options["indel_min_af"])])
command.extend(["--min_bq", str(options["min_bq"])])
if target_bed:
    command.extend(["--bed_fn", target_bed])
if candidate_vcf:
    command.extend(["--hybrid_mode_vcf_fn", candidate_vcf])
if genotyping_vcf:
    command.extend(["--genotyping_mode_vcf_fn", genotyping_vcf])

command_metadata = {
    "schema": "wf-human-variation.somatic_tumour_only_snv_command.v1",
    "task_key": contract["task_key"],
    "tool": "clairs_to",
    "run_clairs_to": command,
    "environment": {
        "CLAIR_MODELS_PATH": str(model_path.parent),
        "CLAIR_DBS_PATH": os.environ["CLAIRS_TO_DATABASE_BUNDLE"],
    },
    "effective_postprocess_qual": str(options["qual"]),
    "structured_options": options,
    "runtime_platform": options["platform"],
    "optional_inputs": {
        "target_bed": target_bed or None,
        "candidate_vcf": candidate_vcf or None,
        "genotyping_vcf": genotyping_vcf or None,
    },
}
Path("somatic_tumour_only_snv_command.json").write_text(json.dumps(command_metadata, indent=2, sort_keys=True) + "\\n")
Path("run-clairs-to.command.sh").write_text(
    "export CLAIR_MODELS_PATH=" + shlex.quote(str(model_path.parent)) + "\\n" +
    "export CLAIR_DBS_PATH=" + shlex.quote(os.environ["CLAIRS_TO_DATABASE_BUNDLE"]) + "\\n" +
    " ".join(shlex.quote(part) for part in command) + "\\n"
)

with Path("somatic_tumour_only_snv.log").open("w") as log:
    subprocess.run(["bash", "run-clairs-to.command.sh"], check=True, stdout=log, stderr=subprocess.STDOUT)
PY

    python3 - <<'PY'
import datetime
import json
import shutil
import subprocess
from pathlib import Path


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


def copy_output(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def find_final_vcf(sample_id):
    preferred = [
        Path(f"{sample_id}.wf-somatic-snv.vcf.gz"),
        Path("clairs_to_output") / f"{sample_id}.wf-somatic-snv.vcf.gz",
        Path("clairs_to_output") / "output.vcf.gz",
        Path("clairs_to_output") / "merge_output.vcf.gz",
    ]
    for candidate in preferred:
        if candidate.exists():
            return candidate
    candidates = sorted(Path("clairs_to_output").rglob("*.vcf.gz")) if Path("clairs_to_output").exists() else []
    if not candidates:
        raise FileNotFoundError("ClairS-TO did not produce a final compressed VCF under clairs_to_output")
    return candidates[0]


contract = json.loads(Path("bounded-somatic-tumour-only-snv-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
command_metadata = json.loads(Path("somatic_tumour_only_snv_command.json").read_text())
sample_id = contract["sample_id"]
final_vcf_name = f"{sample_id}.wf-somatic-snv.vcf.gz"
final_index_name = f"{final_vcf_name}.tbi"

vcf_source = find_final_vcf(sample_id)
index_source = Path(str(vcf_source) + ".tbi")
if not index_source.exists():
    subprocess.run(["tabix", "-f", "-p", "vcf", str(vcf_source)], check=True)
if not index_source.exists():
    raise FileNotFoundError(f"ClairS-TO final VCF index was not produced for {vcf_source}")

shutil.copy2(vcf_source, final_vcf_name)
shutil.copy2(index_source, final_index_name)

optional_inputs = {
    "target_bed": {
        "path": contract["target_bed"] or None,
        "digest": contract["target_bed_digest"] or None,
        "state": "provided" if contract["target_bed"] else "optional_not_provided",
    },
    "candidate_vcf": {
        "path": contract["candidate_vcf"] or None,
        "digest": contract["candidate_vcf_digest"] or None,
        "state": "provided" if contract["candidate_vcf"] else "optional_not_provided",
    },
    "genotyping_vcf": {
        "path": contract["genotyping_vcf"] or None,
        "digest": contract["genotyping_vcf_digest"] or None,
        "state": "provided" if contract["genotyping_vcf"] else "optional_not_provided",
    },
}
manifest = {
    "schema": "wf-human-variation.somatic_tumour_only_snv_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "role": contract["role"],
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "aggregate_xam": contract["aggregate_xam"],
    "aggregate_xam_digest": contract["aggregate_xam_digest"],
    "clairs_to_model": contract["clairs_to_model"],
    "clairs_to_model_name": contract["clairs_to_model_name"] or Path(contract["clairs_to_model"]).name,
    "clairs_to_model_digest": contract["clairs_to_model_digest"],
    "clairs_to_model_table_digest": contract["clairs_to_model_table_digest"],
    "clairs_to_database_bundle_digest": contract["clairs_to_database_bundle_digest"],
    "clairs_to_config_digest": contract["clairs_to_config_digest"],
    "clairs_to_options_digest": contract["clairs_to_options_digest"],
    "container_digest": contract["container_digest"],
    "optional_inputs": optional_inputs,
    "outputs": {
        "somatic_snv_vcf": str(output_paths["somatic_snv_vcf"]),
        "somatic_snv_vcf_index": str(output_paths["somatic_snv_vcf_index"]),
        "somatic_tumour_only_snv_manifest": str(output_paths["somatic_tumour_only_snv_manifest"]),
        "somatic_tumour_only_snv_command_json": str(output_paths["somatic_tumour_only_snv_command_json"]),
        "somatic_tumour_only_snv_logs": str(output_paths["somatic_tumour_only_snv_logs"]),
    },
    "removed_products": {
        "html_report": {"available": False, "reason": "removed_from_humvar3_contract"},
        "igv_config": {"available": False, "reason": "removed_from_humvar3_contract"},
    },
}
Path("somatic_tumour_only_snv_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.somatic_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "tool": "clairs_to",
    "container_digest": contract["container_digest"],
    "command_arguments": command_metadata,
    "input_checksums": {
        "aggregate_xam": contract["aggregate_xam_digest"],
        "aggregate_xam_index": contract["aggregate_xam_index_digest"],
        "reference": contract["reference_digest"],
        "clairs_to_model": contract["clairs_to_model_digest"],
        "clairs_to_model_table": contract["clairs_to_model_table_digest"],
        "clairs_to_database_bundle": contract["clairs_to_database_bundle_digest"],
        "clairs_to_config": contract["clairs_to_config_digest"],
        "clairs_to_options": contract["clairs_to_options_digest"],
        "target_bed": contract["target_bed_digest"] or None,
        "candidate_vcf": contract["candidate_vcf_digest"] or None,
        "genotyping_vcf": contract["genotyping_vcf_digest"] or None,
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
}
Path("somatic_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.somatic_tumour_only_snv_qc.v1",
    "analysis_intent_id": contract["analysis_intent_id"],
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "task_key": contract["task_key"],
    "somatic_snv_vcf": str(output_paths["somatic_snv_vcf"]),
    "log": str(output_paths["somatic_tumour_only_snv_logs"]),
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

for kind, source in {
    "somatic_snv_vcf": Path(final_vcf_name),
    "somatic_snv_vcf_index": Path(final_index_name),
    "somatic_tumour_only_snv_manifest": Path("somatic_tumour_only_snv_manifest.json"),
    "somatic_tumour_only_snv_command_json": Path("somatic_tumour_only_snv_command.json"),
    "somatic_tumour_only_snv_logs": Path("somatic_tumour_only_snv.log"),
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
        "role": contract["role"],
        "sample_id": contract["sample_id"],
        "reference_id": contract["reference_id"],
        "clairs_to_model_name": manifest["clairs_to_model_name"],
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
