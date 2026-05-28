process runBoundedSomaticPairedSvTask {
    label "somatic_severus"
    tag "${entry.analysis_intent_id}:${entry.pair_id}:${entry.reference_id}:${entry.task_key}"

    cpus { entry.severus_options.threads }
    memory { 48.GB * task.attempt }
    maxRetries 1
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }

    input:
        val entry
        val contract_json
        path tumour_aggregate_xam
        path tumour_aggregate_xam_index
        path normal_or_control_aggregate_xam
        path normal_or_control_aggregate_xam_index
        path reference
        path reference_index
        path pon_file
        path trf_bed

    output:
        path "${entry.pair_id}.wf-somatic-sv.vcf.gz", emit: somatic_sv_vcf
        path "${entry.pair_id}.wf-somatic-sv.vcf.gz.tbi", emit: somatic_sv_vcf_index
        path "severus-output", emit: somatic_sv_raw_directory
        path "somatic_paired_sv_manifest.json", emit: somatic_paired_sv_manifest
        path "somatic_paired_sv_command.json", emit: somatic_paired_sv_command_json
        path "somatic_provenance.json", emit: somatic_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-somatic-paired-sv-contract.json <<'JSON'
${contract_json}
JSON

    export TUMOUR_XAM="${tumour_aggregate_xam}"
    export TUMOUR_XAM_INDEX="${tumour_aggregate_xam_index}"
    export NORMAL_OR_CONTROL_XAM="${normal_or_control_aggregate_xam}"
    export NORMAL_OR_CONTROL_XAM_INDEX="${normal_or_control_aggregate_xam_index}"
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


def optional_path(contract, name, staged_env):
    value = contract.get(name) or ""
    if not value:
        return ""
    staged = Path(os.environ[staged_env])
    if not staged.exists():
        raise FileNotFoundError(f"{name} was declared but does not exist in the work directory: {staged}")
    return str(staged)


def required_path(name, env_name):
    staged = Path(os.environ[env_name])
    if not staged.exists():
        raise FileNotFoundError(f"{name} was not staged at the Nextflow boundary: {staged}")
    return str(staged)


def link_input(source, target):
    target_path = Path(target)
    if target_path.exists() or target_path.is_symlink():
        target_path.unlink()
    target_path.symlink_to(Path(source).resolve())


def severus_names(prefix, kind):
    if kind == "cram":
        return f"{prefix}.cram", f"{prefix}.cram.crai"
    if kind == "bam":
        return f"{prefix}.bam", f"{prefix}.bam.bai"
    raise ValueError(f"unsupported aggregate_xam_kind for Severus: {kind}")


contract = json.loads(Path("bounded-somatic-paired-sv-contract.json").read_text())
options = contract["severus_options"]
tumour_xam, tumour_index = severus_names("tumor", contract.get("tumour_aggregate_xam_kind", "bam"))
normal_xam, normal_index = severus_names("normal", contract.get("normal_or_control_aggregate_xam_kind", "bam"))
link_input(os.environ["TUMOUR_XAM"], tumour_xam)
link_input(os.environ["TUMOUR_XAM_INDEX"], tumour_index)
link_input(os.environ["NORMAL_OR_CONTROL_XAM"], normal_xam)
link_input(os.environ["NORMAL_OR_CONTROL_XAM_INDEX"], normal_index)

pon_file = optional_path(contract, "pon_file", "STAGED_PON_FILE")
trf_bed = required_path("trf_bed", "STAGED_TRF_BED")
command = [
    "severus",
    "--target-bam", tumour_xam,
    "--control-bam", normal_xam,
    "--out-dir", "severus-output",
    "--threads", str(options["threads"]),
    "--vntr-bed", trf_bed,
]
if pon_file:
    command.extend(["--PON", pon_file])
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
    "schema": "wf-human-variation.somatic_paired_sv_command.v1",
    "task_key": contract["task_key"],
    "tool": "severus",
    "severus": command,
    "target_xam": tumour_xam,
    "control_xam": normal_xam,
    "structured_options": options,
    "optional_inputs": {
        "pon_file": pon_file or None,
    },
    "required_inputs": {
        "trf_bed": trf_bed,
    },
}
Path("somatic_paired_sv_command.json").write_text(json.dumps(command_metadata, indent=2, sort_keys=True) + "\\n")
Path("run-severus-paired.command.sh").write_text(" ".join(shlex.quote(part) for part in command) + "\\n")

with Path("somatic_paired_sv.log").open("w") as log:
    subprocess.run(["bash", "run-severus-paired.command.sh"], check=True, stdout=log, stderr=subprocess.STDOUT)
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


contract = json.loads(Path("bounded-somatic-paired-sv-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
command_metadata = json.loads(Path("somatic_paired_sv_command.json").read_text())
pair_id = contract["pair_id"]
final_vcf = Path(f"{pair_id}.wf-somatic-sv.vcf.gz")
final_index = Path(f"{pair_id}.wf-somatic-sv.vcf.gz.tbi")
raw_vcf = find_severus_vcf()
Path("sample_rename.txt").write_text(
    f"tumor\\t{contract['tumour_sample_id']}\\nnormal\\t{contract['normal_or_control_sample_id']}\\n"
)
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
}
manifest = {
    "schema": "wf-human-variation.somatic_paired_sv_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "paired_role": contract["paired_role"],
    "tumour_sample_id": contract["tumour_sample_id"],
    "normal_or_control_sample_id": contract["normal_or_control_sample_id"],
    "reference_id": contract["reference_id"],
    "reference_genome_build": contract["reference_genome_build"] or None,
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
    "tumour_aggregate_xam": contract["tumour_aggregate_xam"],
    "tumour_aggregate_xam_kind": contract["tumour_aggregate_xam_kind"],
    "normal_or_control_aggregate_xam": contract["normal_or_control_aggregate_xam"],
    "normal_or_control_aggregate_xam_kind": contract["normal_or_control_aggregate_xam_kind"],
    "severus_config_digest": contract["severus_config_digest"],
    "severus_options_digest": contract["severus_options_digest"],
    "container_digest": contract["container_digest"],
    "optional_inputs": optional_inputs,
    "required_inputs": {
        "trf_bed": {"path": contract["trf_bed"], "digest": contract["trf_bed_digest"]},
    },
    "outputs": {
        "somatic_sv_vcf": str(output_paths["somatic_sv_vcf"]),
        "somatic_sv_vcf_index": str(output_paths["somatic_sv_vcf_index"]),
        "somatic_sv_raw_directory": str(output_paths["somatic_sv_raw_directory"]),
        "somatic_paired_sv_manifest": str(output_paths["somatic_paired_sv_manifest"]),
        "somatic_paired_sv_command_json": str(output_paths["somatic_paired_sv_command_json"]),
    },
    "removed_products": {
        "html_report": {"available": False, "reason": "removed_from_humvar3_contract"},
        "igv_config": {"available": False, "reason": "removed_from_humvar3_contract"},
        "hidden_default_pon": {"available": False, "reason": "controller_declared_asset_required"},
        "hidden_default_trf_bed": {"available": False, "reason": "controller_declared_asset_required"},
        "free_form_shell_arguments": {"available": False, "reason": "structured_options_required"},
    },
}
Path("somatic_paired_sv_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.somatic_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "tool": "severus",
    "container_digest": contract["container_digest"],
    "command_arguments": {
        **command_metadata,
        "finalise": sort_command,
    },
    "input_checksums": {
        "tumour_aggregate_xam": contract["tumour_aggregate_xam_digest"],
        "tumour_aggregate_xam_index": contract["tumour_aggregate_xam_index_digest"],
        "normal_or_control_aggregate_xam": contract["normal_or_control_aggregate_xam_digest"],
        "normal_or_control_aggregate_xam_index": contract["normal_or_control_aggregate_xam_index_digest"],
        "reference": contract["reference_digest"],
        "pon_file": contract["pon_file_digest"] or None,
        "trf_bed": contract["trf_bed_digest"],
        "severus_config": contract["severus_config_digest"],
        "severus_options": contract["severus_options_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
}
Path("somatic_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.somatic_paired_sv_qc.v1",
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
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
    "somatic_paired_sv_manifest": Path("somatic_paired_sv_manifest.json"),
    "somatic_paired_sv_command_json": Path("somatic_paired_sv_command.json"),
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
        "reference_id": contract["reference_id"],
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
