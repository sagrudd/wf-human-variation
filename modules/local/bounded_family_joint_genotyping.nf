process runBoundedFamilyJointGenotypingTask {
    label "wftrio"
    tag "${entry.family_id}:${entry.analysis_intent_id}:${entry.reference_id}:${entry.task_key}"

    cpus { Math.max(2, entry.family_joint_genotyping_options.threads as int) }
    memory { 8.GB * task.attempt }
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }
    maxRetries 3

    input:
        val entry
        val contract_json
        path proband_snp_gvcf
        path proband_snp_gvcf_index
        path father_snp_gvcf
        path father_snp_gvcf_index
        path mother_snp_gvcf
        path mother_snp_gvcf_index
        path glnexus_config
        path pedigree_snapshot
        path reference
        path reference_index

    output:
        path "family_joint.vcf.gz", emit: family_joint_vcf
        path "family_joint.vcf.gz.tbi", emit: family_joint_vcf_index
        path "family_joint_genotyping_manifest.json", emit: family_joint_genotyping_manifest
        path "family_provenance.json", emit: family_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-family-joint-genotyping-contract.json <<'JSON'
${contract_json}
JSON

    cp "${proband_snp_gvcf}" proband.gvcf.gz
    cp "${proband_snp_gvcf_index}" proband.gvcf.gz.tbi
    cp "${father_snp_gvcf}" paternal.gvcf.gz
    cp "${father_snp_gvcf_index}" paternal.gvcf.gz.tbi
    cp "${mother_snp_gvcf}" maternal.gvcf.gz
    cp "${mother_snp_gvcf_index}" maternal.gvcf.gz.tbi
    cp "${glnexus_config}" gl_config.yml

    export PEDIGREE_SNAPSHOT="${pedigree_snapshot}"
    export REFERENCE_FASTA="${reference}"
    python3 - <<'PY'
import datetime
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


def run_command(cmd, commands):
    commands.append(cmd)
    return subprocess.run(cmd, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def copy_output(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def load_pedigree(path):
    text = path.read_text().strip()
    if not text:
        raise ValueError("pedigree snapshot is empty")
    if path.suffix.lower() == ".json" or text.startswith("{"):
        data = json.loads(text)
        memberships = data.get("family_memberships", data.get("memberships", data))
        if isinstance(memberships, dict):
            return {
                str(item.get("role", "")): str(item.get("sample_id", ""))
                for item in memberships.values()
                if isinstance(item, dict)
            }
        if isinstance(memberships, list):
            return {
                str(item.get("role", "")): str(item.get("sample_id", ""))
                for item in memberships
                if isinstance(item, dict)
            }
        raise ValueError("pedigree JSON must contain family_memberships or memberships")
    role_samples = {}
    for line in text.splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) < 6:
            continue
        sample_id, father_id, mother_id = parts[1], parts[2], parts[3]
        if father_id != "0" or mother_id != "0":
            role_samples.setdefault("proband", sample_id)
            if father_id != "0":
                role_samples.setdefault("father", father_id)
            if mother_id != "0":
                role_samples.setdefault("mother", mother_id)
    return role_samples


contract = json.loads(Path("bounded-family-joint-genotyping-contract.json").read_text())
options = contract["family_joint_genotyping_options"]
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
expected_role_samples = {
    "proband": contract["proband_sample_id"],
    "father": contract["father_sample_id"],
    "mother": contract["mother_sample_id"],
}
sample_order = [expected_role_samples[role] for role in options["sample_order"]]
Path("samples.lst").write_text("\\n".join(sample_order) + "\\n")

pedigree_role_samples = load_pedigree(Path(os.environ["PEDIGREE_SNAPSHOT"]))
pedigree_mismatches = {
    role: {"expected": sample_id, "observed": pedigree_role_samples.get(role, "")}
    for role, sample_id in expected_role_samples.items()
    if pedigree_role_samples.get(role, "") != sample_id
}
if pedigree_mismatches:
    raise ValueError(f"pedigree snapshot does not match role sample ids: {pedigree_mismatches}")

commands = []
gvcf_samples = {}
for role, gvcf in (
    ("proband", "proband.gvcf.gz"),
    ("father", "paternal.gvcf.gz"),
    ("mother", "maternal.gvcf.gz"),
):
    result = run_command(["bcftools", "query", "-l", gvcf], commands)
    if result.returncode != 0:
        raise RuntimeError(f"bcftools query failed for {role} GVCF: {result.stderr}")
    observed = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    gvcf_samples[role] = observed
    expected = expected_role_samples[role]
    if expected not in observed:
        raise ValueError(f"{role} GVCF does not contain expected sample_id {expected}; observed={observed}")

glnexus_version = "unknown"
version_result = run_command(["bash", "-c", "glnexus_cli 2>&1 | sed 1q"], commands)
if version_result.stdout.strip():
    glnexus_version = version_result.stdout.strip()
elif version_result.stderr.strip():
    glnexus_version = version_result.stderr.strip().splitlines()[0]

threads = str(options["threads"])
joint_cmd = [
    "bash",
    "-c",
    "glnexus_cli --threads "
    + threads
    + " --dir glnexus_DB --config gl_config.yml proband.gvcf.gz paternal.gvcf.gz maternal.gvcf.gz "
    + "| bcftools view --threads 1 -S samples.lst -o family_joint.vcf.gz -O z -",
]
result = run_command(joint_cmd, commands)
failure = None
if result.returncode != 0:
    failure = {"stage": "glnexus_joint_genotyping", "exit_code": result.returncode, "stderr": result.stderr}

if failure is None:
    index_cmd = ["bcftools", "index", "--threads", "1", "-t", "family_joint.vcf.gz"]
    result = run_command(index_cmd, commands)
    if result.returncode != 0:
        failure = {"stage": "index_family_joint_vcf", "exit_code": result.returncode, "stderr": result.stderr}

if failure is not None:
    Path("family_joint_genotyping_manifest.json").write_text(json.dumps({
        "schema": "wf-human-variation.family_joint_genotyping_manifest.v1",
        "task_family": contract["task_family"],
        "task_key": contract["task_key"],
        "family_id": contract["family_id"],
        "analysis_intent_id": contract["analysis_intent_id"],
        "reference_id": contract["reference_id"],
        "state": "failed",
        "failure": failure,
        "sample_order": sample_order,
        "gvcf_samples": gvcf_samples,
    }, indent=2, sort_keys=True) + "\\n")
    sys.exit(1)

manifest = {
    "schema": "wf-human-variation.family_joint_genotyping_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
    "pedigree_snapshot_digest": contract["pedigree_snapshot_digest"],
    "role_sample_ids": expected_role_samples,
    "sample_order": sample_order,
    "gvcf_samples": gvcf_samples,
    "glnexus_version": glnexus_version,
    "glnexus_config_digest": contract["glnexus_config_digest"],
    "reference_digest": contract["reference_digest"],
    "container_digest": contract["container_digest"],
    "outputs": {
        "family_joint_vcf": str(output_paths["family_joint_vcf"]),
        "family_joint_vcf_index": str(output_paths["family_joint_vcf_index"]),
        "family_joint_genotyping_manifest": str(output_paths["family_joint_genotyping_manifest"]),
    },
}
Path("family_joint_genotyping_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.family_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "tool": "glnexus",
    "tool_version": glnexus_version,
    "container_digest": contract["container_digest"],
    "command_arguments": commands,
    "input_checksums": {
        "proband_snp_gvcf": contract["proband_snp_gvcf_digest"],
        "proband_snp_gvcf_index": contract["proband_snp_gvcf_index_digest"],
        "father_snp_gvcf": contract["father_snp_gvcf_digest"],
        "father_snp_gvcf_index": contract["father_snp_gvcf_index_digest"],
        "mother_snp_gvcf": contract["mother_snp_gvcf_digest"],
        "mother_snp_gvcf_index": contract["mother_snp_gvcf_index_digest"],
        "glnexus_config": contract["glnexus_config_digest"],
        "reference": contract["reference_digest"],
        "pedigree_snapshot": contract["pedigree_snapshot_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
}
Path("family_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.family_joint_genotyping_qc.v1",
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "task_key": contract["task_key"],
    "sample_order": sample_order,
    "gvcf_sample_count": sum(len(samples) for samples in gvcf_samples.values()),
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

copies = {
    "family_joint_vcf": Path("family_joint.vcf.gz"),
    "family_joint_vcf_index": Path("family_joint.vcf.gz.tbi"),
    "family_joint_genotyping_manifest": Path("family_joint_genotyping_manifest.json"),
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
        "sample_order": sample_order,
    },
}
tmp_marker = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp_marker.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp_marker.replace(marker_path)
PY
    """
}
