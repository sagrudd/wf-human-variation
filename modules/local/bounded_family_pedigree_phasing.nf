process runBoundedFamilyPedigreePhasingTask {
    label "wftrio"
    tag "${entry.family_id}:${entry.analysis_intent_id}:${entry.reference_id}:${entry.task_key}"

    cpus 2
    memory { 4.GB * task.attempt }
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }
    maxRetries 2

    input:
        val entry
        val contract_json
        path family_joint_vcf
        path family_joint_vcf_index
        path pedigree_snapshot
        path proband_bam
        path proband_bam_index
        path father_bam
        path father_bam_index
        path mother_bam
        path mother_bam_index
        path reference
        path reference_index

    output:
        path "pedigree_filtered.vcf.gz", emit: pedigree_filtered_vcf
        path "pedigree_filtered.vcf.gz.tbi", emit: pedigree_filtered_vcf_index
        path "per_sample_phased_vcf_fragments", emit: per_sample_phased_vcf_fragments
        path "pedigree_phasing_manifest.json", emit: pedigree_phasing_manifest
        path "pedigree_phasing_state.json", emit: pedigree_phasing_state
        path "family_provenance.json", emit: family_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-family-pedigree-phasing-contract.json <<'JSON'
${contract_json}
JSON

    cp "${family_joint_vcf}" family_joint.vcf.gz
    cp "${family_joint_vcf_index}" family_joint.vcf.gz.tbi
    cp "${proband_bam}" proband.bam
    cp "${proband_bam_index}" proband.bam.bai
    cp "${father_bam}" father.bam
    cp "${father_bam_index}" father.bam.bai
    cp "${mother_bam}" mother.bam
    cp "${mother_bam_index}" mother.bam.bai

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
    if source.is_dir():
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(source, target)
    else:
        shutil.copy2(source, target)


def load_pedigree(path, family_id, expected):
    text = path.read_text().strip()
    if not text:
        return {}, "", "empty_pedigree_snapshot"
    if path.suffix.lower() == ".json" or text.startswith("{"):
        data = json.loads(text)
        memberships = data.get("family_memberships", data.get("memberships", data))
        if isinstance(memberships, dict):
            items = [item for item in memberships.values() if isinstance(item, dict)]
        elif isinstance(memberships, list):
            items = [item for item in memberships if isinstance(item, dict)]
        else:
            return {}, "", "invalid_pedigree_json"
        observed = {
            str(item.get("role", "")): str(item.get("sample_id", ""))
            for item in items
            if str(item.get("role", "")) in expected
        }
        ped_line = "\\t".join([
            family_id,
            expected["proband"],
            expected["father"],
            expected["mother"],
            "0",
            "0",
        ]) + "\\n"
        return observed, ped_line, ""

    observed = {}
    ped_line = ""
    for line in text.splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) < 6:
            continue
        if parts[1] == expected["proband"]:
            ped_line = "\\t".join(parts[:6]) + "\\n"
            observed["proband"] = parts[1]
            observed["father"] = parts[2]
            observed["mother"] = parts[3]
            break
    return observed, ped_line, "" if ped_line else "missing_proband_pedigree_row"


contract = json.loads(Path("bounded-family-pedigree-phasing-contract.json").read_text())
options = contract["family_pedigree_phasing_options"]
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
expected_role_samples = {
    "proband": contract["proband_sample_id"],
    "father": contract["father_sample_id"],
    "mother": contract["mother_sample_id"],
}
commands = []
contigs = [str(contig) for contig in options["contigs"]]
fragment_dir = Path("per_sample_phased_vcf_fragments")
for role in ("proband", "father", "mother"):
    (fragment_dir / role).mkdir(parents=True, exist_ok=True)

pedigree_role_samples, ped_line, pedigree_error = load_pedigree(
    Path(os.environ["PEDIGREE_SNAPSHOT"]),
    contract["family_id"],
    expected_role_samples,
)
pedigree_mismatches = {
    role: {"expected": sample_id, "observed": pedigree_role_samples.get(role, "")}
    for role, sample_id in expected_role_samples.items()
    if pedigree_role_samples.get(role, "") != sample_id
}

failure = None
state = "completed"
if not options["enabled"]:
    state = "skipped_disabled"
elif pedigree_error:
    state = "skipped_impossible_relationship_graph"
    failure = {"stage": "pedigree_validation", "reason": pedigree_error}
elif pedigree_mismatches:
    state = "skipped_impossible_relationship_graph"
    failure = {"stage": "pedigree_validation", "mismatches": pedigree_mismatches}

whatshap_version = "unknown"
version_result = run_command(["whatshap", "--version"], commands)
if version_result.returncode == 0 and version_result.stdout.strip():
    whatshap_version = version_result.stdout.strip().splitlines()[0]

phased_contigs = []
if state == "completed":
    Path("edited.ped").write_text(ped_line)
    for contig in contigs:
        cmd = [
            "whatshap",
            "phase",
            "--output",
            f"phased_{contig}.tmp.vcf",
            "--chromosome",
            contig,
            "--ped",
            "edited.ped",
            "--reference",
            os.environ["REFERENCE_FASTA"],
        ]
        if options["only_snvs"]:
            cmd.append("--only-snvs")
        cmd.extend(["family_joint.vcf.gz", "proband.bam", "father.bam", "mother.bam"])
        result = run_command(cmd, commands)
        if result.returncode != 0:
            state = "failed"
            failure = {"stage": "whatshap_phase", "contig": contig, "exit_code": result.returncode, "stderr": result.stderr}
            break
        fix_cmd = [
            "bash",
            "-c",
            f"sed 's/AD,Number=./AD,Number=R/g' phased_{contig}.tmp.vcf | bgzip -c > phased_{contig}.vcf.gz",
        ]
        result = run_command(fix_cmd, commands)
        if result.returncode != 0:
            state = "failed"
            failure = {"stage": "compress_phased_contig", "contig": contig, "exit_code": result.returncode, "stderr": result.stderr}
            break
        index_cmd = ["tabix", "-p", "vcf", f"phased_{contig}.vcf.gz"]
        result = run_command(index_cmd, commands)
        if result.returncode != 0:
            state = "failed"
            failure = {"stage": "index_phased_contig", "contig": contig, "exit_code": result.returncode, "stderr": result.stderr}
            break
        phased_contigs.append(f"phased_{contig}.vcf.gz")

if state == "completed":
    concat_cmd = [
        "bash",
        "-c",
        "bcftools concat --threads 1 -O u "
        + " ".join(phased_contigs)
        + " | bcftools sort -O z - > pedigree_filtered.vcf.gz",
    ]
    result = run_command(concat_cmd, commands)
    if result.returncode != 0:
        state = "failed"
        failure = {"stage": "concat_phased_contigs", "exit_code": result.returncode, "stderr": result.stderr}
    else:
        result = run_command(["tabix", "-p", "vcf", "pedigree_filtered.vcf.gz"], commands)
        if result.returncode != 0:
            state = "failed"
            failure = {"stage": "index_pedigree_filtered_vcf", "exit_code": result.returncode, "stderr": result.stderr}

if state.startswith("skipped_"):
    shutil.copy2("family_joint.vcf.gz", "pedigree_filtered.vcf.gz")
    shutil.copy2("family_joint.vcf.gz.tbi", "pedigree_filtered.vcf.gz.tbi")
elif state == "completed":
    for role, sample_id in expected_role_samples.items():
        out = fragment_dir / role / f"{sample_id}.phased.vcf.gz"
        view_cmd = ["bcftools", "view", "-s", sample_id, "-O", "z", "-o", str(out), "pedigree_filtered.vcf.gz"]
        result = run_command(view_cmd, commands)
        if result.returncode != 0:
            state = "failed"
            failure = {"stage": "extract_per_sample_phased_vcf", "role": role, "exit_code": result.returncode, "stderr": result.stderr}
            break
        result = run_command(["tabix", "-p", "vcf", str(out)], commands)
        if result.returncode != 0:
            state = "failed"
            failure = {"stage": "index_per_sample_phased_vcf", "role": role, "exit_code": result.returncode, "stderr": result.stderr}
            break

Path("pedigree_phasing_state.json").write_text(json.dumps({
    "schema": "wf-human-variation.pedigree_phasing_state.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "state": state,
    "failure": failure,
    "contigs": contigs,
    "phased_contigs": phased_contigs,
}, indent=2, sort_keys=True) + "\\n")

manifest = {
    "schema": "wf-human-variation.pedigree_phasing_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
    "pedigree_snapshot_digest": contract["pedigree_snapshot_digest"],
    "role_sample_ids": expected_role_samples,
    "state": state,
    "whatshap_version": whatshap_version,
    "whatshap_config_digest": contract["whatshap_config_digest"],
    "reference_digest": contract["reference_digest"],
    "container_digest": contract["container_digest"],
    "outputs": {
        "pedigree_filtered_vcf": str(output_paths["pedigree_filtered_vcf"]),
        "pedigree_filtered_vcf_index": str(output_paths["pedigree_filtered_vcf_index"]),
        "per_sample_phased_vcf_fragments": str(output_paths["per_sample_phased_vcf_fragments"]),
        "pedigree_phasing_manifest": str(output_paths["pedigree_phasing_manifest"]),
        "pedigree_phasing_state": str(output_paths["pedigree_phasing_state"]),
    },
}
Path("pedigree_phasing_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.family_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "tool": "whatshap",
    "tool_version": whatshap_version,
    "container_digest": contract["container_digest"],
    "command_arguments": commands,
    "input_checksums": {
        "family_joint_vcf": contract["family_joint_vcf_digest"],
        "family_joint_vcf_index": contract["family_joint_vcf_index_digest"],
        "proband_bam": contract["proband_bam_digest"],
        "proband_bam_index": contract["proband_bam_index_digest"],
        "father_bam": contract["father_bam_digest"],
        "father_bam_index": contract["father_bam_index_digest"],
        "mother_bam": contract["mother_bam_digest"],
        "mother_bam_index": contract["mother_bam_index_digest"],
        "pedigree_snapshot": contract["pedigree_snapshot_digest"],
        "reference": contract["reference_digest"],
        "whatshap_config": contract["whatshap_config_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
}
Path("family_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.pedigree_phasing_qc.v1",
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "task_key": contract["task_key"],
    "state": state,
    "contig_count": len(contigs),
    "phased_contig_count": len(phased_contigs),
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

if state == "failed":
    for kind, source in {
        "pedigree_phasing_manifest": Path("pedigree_phasing_manifest.json"),
        "pedigree_phasing_state": Path("pedigree_phasing_state.json"),
        "family_provenance": Path("family_provenance.json"),
        "qc_stats": Path("qc_stats.json"),
    }.items():
        copy_output(source, output_paths[kind])
    sys.exit(1)

copies = {
    "pedigree_filtered_vcf": Path("pedigree_filtered.vcf.gz"),
    "pedigree_filtered_vcf_index": Path("pedigree_filtered.vcf.gz.tbi"),
    "per_sample_phased_vcf_fragments": fragment_dir,
    "pedigree_phasing_manifest": Path("pedigree_phasing_manifest.json"),
    "pedigree_phasing_state": Path("pedigree_phasing_state.json"),
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
        "state": state,
        "phased_contig_count": len(phased_contigs),
    },
}
tmp_marker = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp_marker.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp_marker.replace(marker_path)
PY
    """
}
