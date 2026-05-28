process runBoundedSomaticTumourOnlySvTask {
    label "somatic_severus"
    tag "${entry.analysis_intent_id}:${entry.sample_id}:${entry.reference_id}:${entry.task_key}"

    cpus { entry.severus_options.threads }
    memory { 48.GB * task.attempt }
    maxRetries 1
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }

    input:
        val entry
        val contract_json
        path aggregate_xam
        path aggregate_xam_index
        path reference
        path reference_index
        path pon_file
        path trf_bed

    output:
        path "${entry.sample_id}.wf-somatic-sv.vcf.gz", emit: somatic_sv_vcf
        path "${entry.sample_id}.wf-somatic-sv.vcf.gz.tbi", emit: somatic_sv_vcf_index
        path "severus-output", emit: somatic_sv_raw_directory
        path "somatic_tumour_only_sv_manifest.json", emit: somatic_tumour_only_sv_manifest
        path "somatic_tumour_only_sv_command.json", emit: somatic_tumour_only_sv_command_json
        path "somatic_provenance.json", emit: somatic_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-somatic-tumour-only-sv-contract.json <<'JSON'
${contract_json}
JSON

    export AGGREGATE_XAM="${aggregate_xam}"
    export AGGREGATE_XAM_INDEX="${aggregate_xam_index}"
    export REFERENCE_FASTA="${reference}"
    export REFERENCE_INDEX="${reference_index}"
    export STAGED_PON_FILE="${pon_file}"
    export STAGED_TRF_BED="${trf_bed}"
    python3 - <<'PY'
import json
import os
import shlex
import subprocess
from pathlib import Path


ABSENT_PREFIX = "__wf_human_variation_absent_input__"


def optional_path(contract, name, staged_env):
    value = contract.get(name) or ""
    if not value:
        return ""
    staged = Path(os.environ[staged_env])
    if staged.name == ABSENT_PREFIX or staged.name.startswith(f"{ABSENT_PREFIX}."):
        raise FileNotFoundError(f"{name} was declared but was not staged at the Nextflow boundary")
    if not staged.exists():
        raise FileNotFoundError(f"{name} was declared but does not exist in the work directory: {staged}")
    return str(staged)


def link_input(source, target):
    target_path = Path(target)
    if target_path.exists() or target_path.is_symlink():
        target_path.unlink()
    target_path.symlink_to(Path(source).resolve())


contract = json.loads(Path("bounded-somatic-tumour-only-sv-contract.json").read_text())
options = contract["severus_options"]
kind = contract.get("aggregate_xam_kind", "bam")
if kind not in {"bam", "cram"}:
    raise ValueError(f"unsupported aggregate_xam_kind for Severus: {kind}")
target_xam = "tumor.cram" if kind == "cram" else "tumor.bam"
target_index = "tumor.cram.crai" if kind == "cram" else "tumor.bam.bai"
link_input(os.environ["AGGREGATE_XAM"], target_xam)
link_input(os.environ["AGGREGATE_XAM_INDEX"], target_index)

pon_file = optional_path(contract, "pon_file", "STAGED_PON_FILE")
trf_bed = optional_path(contract, "trf_bed", "STAGED_TRF_BED")
command = [
    "severus",
    "--target-bam", target_xam,
    "--out-dir", "severus-output",
    "--threads", str(options["threads"]),
]
if pon_file:
    command.extend(["--PON", pon_file])
if trf_bed:
    command.extend(["--vntr-bed", trf_bed])
if options["single_bp"]:
    command.append("--single-bp")
if options["resolve_overlaps"]:
    command.append("--resolve-overlaps")
if options["between_junction_ins"]:
    command.append("--between-junction-ins")
if options["vaf_threshold"] is not None:
    command.extend(["--vaf-thr", str(options["vaf_threshold"])])
command.extend(["--min-sv-size", str(options["min_sv_length"])])
command.extend(["--min-support", str(options["min_support"])])

command_metadata = {
    "schema": "wf-human-variation.somatic_tumour_only_sv_command.v1",
    "task_key": contract["task_key"],
    "tool": "severus",
    "severus": command,
    "target_xam": target_xam,
    "structured_options": options,
    "optional_inputs": {
        "pon_file": pon_file or None,
        "trf_bed": trf_bed or None,
    },
}
Path("somatic_tumour_only_sv_command.json").write_text(json.dumps(command_metadata, indent=2, sort_keys=True) + "\\n")
Path("run-severus.command.sh").write_text(" ".join(shlex.quote(part) for part in command) + "\\n")

with Path("somatic_tumour_only_sv.log").open("w") as log:
    subprocess.run(["bash", "run-severus.command.sh"], check=True, stdout=log, stderr=subprocess.STDOUT)
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
    if source.is_dir():
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(source, target)
    else:
        shutil.copy2(source, target)


def find_severus_vcf():
    preferred = [
        Path("severus-output/somatic_SVs/severus_somatic.vcf"),
        Path("severus-output/severus_somatic.vcf"),
    ]
    for candidate in preferred:
        if candidate.exists():
            return candidate
    candidates = sorted(Path("severus-output").rglob("*.vcf")) if Path("severus-output").exists() else []
    if not candidates:
        raise FileNotFoundError("Severus did not produce a VCF under severus-output")
    return candidates[0]


contract = json.loads(Path("bounded-somatic-tumour-only-sv-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
command_metadata = json.loads(Path("somatic_tumour_only_sv_command.json").read_text())
sample_id = contract["sample_id"]
final_vcf = Path(f"{sample_id}.wf-somatic-sv.vcf.gz")
final_index = Path(f"{sample_id}.wf-somatic-sv.vcf.gz.tbi")
raw_vcf = find_severus_vcf()
Path("sample_rename.txt").write_text(f"tumor\\t{sample_id}\\n")
sort_command = [
    "bash",
    "-lc",
    "bcftools sort -m 2G -O v "
    + str(raw_vcf)
    + " | bcftools reheader -s sample_rename.txt -"
    + " | bcftools filter --threads "
    + str(contract["severus_options"]["threads"] if contract["severus_options"]["threads"] >= 2 else 2)
    + " -e 'INFO/END < POS & INFO/SVTYPE == \"INV\"'"
    + " | bgzip -c > "
    + str(final_vcf),
]
subprocess.run(sort_command, check=True)
subprocess.run(["bcftools", "index", "--threads", str(contract["severus_options"]["threads"]), "-t", str(final_vcf)], check=True)
if not final_index.exists():
    raise FileNotFoundError(f"final Severus index was not produced: {final_index}")

optional_inputs = {
    "pon_file": {
        "path": contract["pon_file"] or None,
        "digest": contract["pon_file_digest"] or None,
        "state": "provided" if contract["pon_file"] else "optional_not_provided",
    },
    "trf_bed": {
        "path": contract["trf_bed"] or None,
        "digest": contract["trf_bed_digest"] or None,
        "state": "provided" if contract["trf_bed"] else "optional_not_provided",
    },
}
manifest = {
    "schema": "wf-human-variation.somatic_tumour_only_sv_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "role": contract["role"],
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "reference_genome_build": contract["reference_genome_build"] or None,
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "aggregate_xam": contract["aggregate_xam"],
    "aggregate_xam_kind": contract["aggregate_xam_kind"],
    "aggregate_xam_digest": contract["aggregate_xam_digest"],
    "severus_config_digest": contract["severus_config_digest"],
    "severus_options_digest": contract["severus_options_digest"],
    "container_digest": contract["container_digest"],
    "optional_inputs": optional_inputs,
    "outputs": {
        "somatic_sv_vcf": str(output_paths["somatic_sv_vcf"]),
        "somatic_sv_vcf_index": str(output_paths["somatic_sv_vcf_index"]),
        "somatic_sv_raw_directory": str(output_paths["somatic_sv_raw_directory"]),
        "somatic_tumour_only_sv_manifest": str(output_paths["somatic_tumour_only_sv_manifest"]),
        "somatic_tumour_only_sv_command_json": str(output_paths["somatic_tumour_only_sv_command_json"]),
    },
    "removed_products": {
        "html_report": {"available": False, "reason": "removed_from_humvar3_contract"},
        "igv_config": {"available": False, "reason": "removed_from_humvar3_contract"},
        "hidden_default_pon": {"available": False, "reason": "controller_declared_asset_required"},
        "hidden_default_trf_bed": {"available": False, "reason": "controller_declared_asset_required"},
    },
}
Path("somatic_tumour_only_sv_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.somatic_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "tool": "severus",
    "container_digest": contract["container_digest"],
    "command_arguments": {
        **command_metadata,
        "finalise": sort_command,
    },
    "input_checksums": {
        "aggregate_xam": contract["aggregate_xam_digest"],
        "aggregate_xam_index": contract["aggregate_xam_index_digest"],
        "reference": contract["reference_digest"],
        "pon_file": contract["pon_file_digest"] or None,
        "trf_bed": contract["trf_bed_digest"] or None,
        "severus_config": contract["severus_config_digest"],
        "severus_options": contract["severus_options_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
}
Path("somatic_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.somatic_tumour_only_sv_qc.v1",
    "analysis_intent_id": contract["analysis_intent_id"],
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "task_key": contract["task_key"],
    "somatic_sv_vcf": str(output_paths["somatic_sv_vcf"]),
    "raw_directory": str(output_paths["somatic_sv_raw_directory"]),
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

for kind, source in {
    "somatic_sv_vcf": final_vcf,
    "somatic_sv_vcf_index": final_index,
    "somatic_sv_raw_directory": Path("severus-output"),
    "somatic_tumour_only_sv_manifest": Path("somatic_tumour_only_sv_manifest.json"),
    "somatic_tumour_only_sv_command_json": Path("somatic_tumour_only_sv_command.json"),
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
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
