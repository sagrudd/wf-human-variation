process runBoundedFamilySvMergingTask {
    label "wf_human_sv"
    tag "${entry.family_id}:${entry.analysis_intent_id}:${entry.reference_id}:${entry.task_key}"

    cpus { entry.family_sv_merging_options.threads }
    memory 8.GB

    input:
        val entry
        val contract_json
        path proband_snf
        path father_snf
        path mother_snf
        path reference
        path reference_index
        path target_bed

    output:
        path "family_sv.vcf.gz", emit: family_sv_vcf
        path "family_sv.vcf.gz.tbi", emit: family_sv_vcf_index
        path "family_sv_merging_command.json", emit: family_sv_merging_command_json
        path "family_sv_merging_manifest.json", emit: family_sv_merging_manifest
        path "family_sv_merging_state.json", emit: family_sv_merging_state
        path "family_provenance.json", emit: family_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-family-sv-merging-contract.json <<'JSON'
${contract_json}
JSON

    export PROBAND_SNF="${proband_snf}"
    export FATHER_SNF="${father_snf}"
    export MOTHER_SNF="${mother_snf}"
    export REFERENCE_FASTA="${reference}"
    export TARGET_BED="${target_bed}"
    python3 - <<'PY'
import datetime
import json
import os
import shlex
import shutil
import subprocess
from pathlib import Path


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


def run_command(cmd, commands):
    commands.append(cmd)
    return subprocess.run(cmd, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def copy_output(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


contract = json.loads(Path("bounded-family-sv-merging-contract.json").read_text())
options = contract["family_sv_merging_options"]
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
selected_roles = [str(role) for role in options["roles"]]
role_env = {
    "proband": "PROBAND_SNF",
    "father": "FATHER_SNF",
    "mother": "MOTHER_SNF",
}
commands = {}
executed = []
state = "completed" if len(selected_roles) == 3 else "completed_subset"
failure = None

Path("snfs").mkdir(exist_ok=True)
staged_snfs = []
role_inputs = {}
for role in selected_roles:
    sample_id = contract[f"{role}_sample_id"]
    source = Path(os.environ[role_env[role]])
    if not source.exists():
        raise FileNotFoundError(f"{role} SNF does not exist: {source}")
    reference_digest = contract[f"{role}_snf_reference_digest"]
    if reference_digest != contract["reference_digest"]:
        raise ValueError(f"{role} SNF reference digest does not match requested reference")
    genome_build = contract.get(f"{role}_snf_genome_build", "")
    if options["genome_build"] and genome_build and genome_build != options["genome_build"]:
        raise ValueError(f"{role} SNF genome build does not match family SV merging options")
    staged = Path("snfs") / f"{role}.{sample_id}.snf"
    shutil.copy2(source, staged)
    staged_snfs.append(staged)
    role_inputs[role] = {
        "sample_id": sample_id,
        "snf": str(staged),
        "snf_digest": contract[f"{role}_snf_digest"],
        "snf_reference_digest": reference_digest,
        "snf_genome_build": genome_build,
    }

sniffles_version = "unknown"
version = run_command(["sniffles", "--version"], executed)
if version.returncode == 0 and version.stdout.strip():
    sniffles_version = version.stdout.strip().splitlines()[0]

sniffles_cmd = [
    "sniffles",
    "--threads", str(options["threads"]),
    "--vcf", "family_sv.raw.vcf",
    "--reference", os.environ["REFERENCE_FASTA"],
]
if int(options["min_sv_length"]) > 0:
    sniffles_cmd.extend(["--minsvlen", str(options["min_sv_length"])])
sniffles_script = " ".join(shlex.quote(part) for part in sniffles_cmd)
sniffles_script += " --input " + " ".join(shlex.quote(str(path)) for path in staged_snfs)
commands["sniffles_joint_merge"] = sniffles_cmd + ["--input"] + [str(path) for path in staged_snfs]
result = run_command(["bash", "-c", sniffles_script], executed)
if result.returncode != 0:
    state = "failed"
    failure = {"stage": "sniffles_joint_merge", "exit_code": result.returncode, "stderr": result.stderr}

if state != "failed":
    result = run_command(["bcftools", "view", "-U", "-O", "z", "-o", "family_sv.unsorted.vcf.gz", "family_sv.raw.vcf"], executed)
    if result.returncode != 0:
        state = "failed"
        failure = {"stage": "bcftools_view_merged_vcf", "exit_code": result.returncode, "stderr": result.stderr}

if state != "failed":
    result = run_command(["tabix", "-p", "vcf", "family_sv.unsorted.vcf.gz"], executed)
    if result.returncode != 0:
        state = "failed"
        failure = {"stage": "index_unsorted_family_sv_vcf", "exit_code": result.returncode, "stderr": result.stderr}

if state != "failed":
    filter_cmd = ["bcftools", "view", "--threads", str(options["threads"]), "-O", "z", "-o", "family_sv.filtered.vcf.gz"]
    if not options["include_all_ctgs"]:
        filter_cmd.extend(["-r", ",".join(str(code) for code in options["chromosome_codes"])])
    filter_cmd.extend(["-T", os.environ["TARGET_BED"], "--targets-overlap", "1", "family_sv.unsorted.vcf.gz"])
    commands["bcftools_filter"] = filter_cmd
    result = run_command(filter_cmd, executed)
    if result.returncode != 0:
        state = "failed"
        failure = {"stage": "filter_family_sv_vcf", "exit_code": result.returncode, "stderr": result.stderr}

if state != "failed":
    result = run_command(["bcftools", "sort", "-m", "2G", "-T", "./", "-O", "z", "-o", "family_sv.vcf.gz", "family_sv.filtered.vcf.gz"], executed)
    if result.returncode != 0:
        state = "failed"
        failure = {"stage": "sort_family_sv_vcf", "exit_code": result.returncode, "stderr": result.stderr}

if state != "failed":
    result = run_command(["tabix", "-p", "vcf", "family_sv.vcf.gz"], executed)
    if result.returncode != 0:
        state = "failed"
        failure = {"stage": "index_family_sv_vcf", "exit_code": result.returncode, "stderr": result.stderr}

commands["executed"] = executed
Path("family_sv_merging_command.json").write_text(json.dumps(commands, indent=2, sort_keys=True) + "\\n")

state_payload = {
    "schema": "wf-human-variation.family_sv_merging_state.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "state": state,
    "failure": failure,
    "roles": selected_roles,
    "allow_subset": options["allow_subset"],
}
Path("family_sv_merging_state.json").write_text(json.dumps(state_payload, indent=2, sort_keys=True) + "\\n")

manifest = {
    "schema": "wf-human-variation.family_sv_merging_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
    "state": state,
    "roles": selected_roles,
    "role_inputs": role_inputs,
    "sniffles_version": sniffles_version,
    "sniffles_config_digest": contract["sniffles_config_digest"],
    "target_bed_digest": contract["target_bed_digest"],
    "reference_digest": contract["reference_digest"],
    "container_digest": contract["container_digest"],
    "outputs": {
        "family_sv_vcf": str(output_paths["family_sv_vcf"]),
        "family_sv_vcf_index": str(output_paths["family_sv_vcf_index"]),
        "family_sv_merging_command_json": str(output_paths["family_sv_merging_command_json"]),
        "family_sv_merging_manifest": str(output_paths["family_sv_merging_manifest"]),
        "family_sv_merging_state": str(output_paths["family_sv_merging_state"]),
    },
}
Path("family_sv_merging_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.family_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "tool": "sniffles2",
    "tool_version": sniffles_version,
    "container_digest": contract["container_digest"],
    "command_arguments": commands,
    "input_checksums": {
        "role_snfs": {role: role_inputs[role]["snf_digest"] for role in selected_roles},
        "target_bed": contract["target_bed_digest"],
        "reference": contract["reference_digest"],
        "sniffles_config": contract["sniffles_config_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
}
Path("family_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.family_sv_merging_qc.v1",
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "task_key": contract["task_key"],
    "state": state,
    "role_count": len(selected_roles),
    "family_sv_vcf": str(output_paths["family_sv_vcf"]),
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

for kind, source in {
    "family_sv_merging_command_json": Path("family_sv_merging_command.json"),
    "family_sv_merging_manifest": Path("family_sv_merging_manifest.json"),
    "family_sv_merging_state": Path("family_sv_merging_state.json"),
    "family_provenance": Path("family_provenance.json"),
    "qc_stats": Path("qc_stats.json"),
}.items():
    copy_output(source, output_paths[kind])

if state == "failed":
    raise RuntimeError(f"family SV merging failed: {failure}")

for kind, source in {
    "family_sv_vcf": Path("family_sv.vcf.gz"),
    "family_sv_vcf_index": Path("family_sv.vcf.gz.tbi"),
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
        "family_id": contract["family_id"],
        "analysis_intent_id": contract["analysis_intent_id"],
        "reference_id": contract["reference_id"],
        "state": state,
        "roles": selected_roles,
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
