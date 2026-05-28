process runBoundedTrioDenovoCallingTask {
    label "clair3nova"
    tag "${entry.family_id}:${entry.analysis_intent_id}:${entry.reference_id}:${entry.contig}:${entry.task_key}"

    cpus 2
    memory { 4.GB * task.attempt }
    errorStrategy { task.exitStatus in [134, 137, 140, 142] ? 'retry' : 'finish' }
    maxRetries 1

    input:
        val entry
        val contract_json
        path trio_candidate_beds
        path proband_bam
        path proband_bam_index
        path father_bam
        path father_bam_index
        path mother_bam
        path mother_bam_index
        path reference
        path reference_index
        path clair3_nova_model

    output:
        path "trio_denovo_manifest.json", emit: trio_denovo_manifest
        path "trio_denovo_vcf_fragments", emit: trio_denovo_vcf_fragments
        path "trio_denovo_state.json", emit: trio_denovo_state
        path "trio_denovo_command.json", emit: trio_denovo_command_json
        path "family_provenance.json", emit: family_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-family-germline-snp-denovo-contract.json <<'JSON'
${contract_json}
JSON

    export TRIO_CANDIDATE_BEDS="${trio_candidate_beds}"
    export PROBAND_BAM="${proband_bam}"
    export FATHER_BAM="${father_bam}"
    export MOTHER_BAM="${mother_bam}"
    export REFERENCE_FASTA="${reference}"
    export CLAIR3_NOVA_MODEL="${clair3_nova_model}"

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


def candidate_has_regions(path):
    if not path.exists() or path.stat().st_size == 0:
        return False
    with path.open() as handle:
        for line in handle:
            stripped = line.strip()
            if stripped and not stripped.startswith("#"):
                return True
    return False


def copy_output(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.is_dir():
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(source, target)
    else:
        shutil.copy2(source, target)


contract = json.loads(Path("bounded-family-germline-snp-denovo-contract.json").read_text())
options = contract["family_germline_denovo_options"]
contig = contract["contig"]
candidate_root = Path(os.environ["TRIO_CANDIDATE_BEDS"])
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}

clair3_nova_path = os.environ.get("CLAIR3_NOVA_PATH", "").strip()
if not clair3_nova_path:
    raise EnvironmentError("CLAIR3_NOVA_PATH must be set by the Clair3-Nova container")
clair3_nova_script = str(Path(clair3_nova_path) / "clair3.py")
model_checkpoint = str(Path(os.environ["CLAIR3_NOVA_MODEL"]) / "nova")

Path("tmp").mkdir(exist_ok=True)
Path("tmp/CONTIGS").write_text(str(contig) + "\\n")
fragment_root = Path("trio_denovo_vcf_fragments")
for role in ("proband", "father", "mother"):
    (fragment_root / role).mkdir(parents=True, exist_ok=True)

candidate_files = sorted(path for path in candidate_root.glob(f"{contig}.*") if path.is_file())
commands = []
region_states = []
failures = []
callable_regions = 0

for candidate_bed in candidate_files:
    region_label = safe_component(candidate_bed.name)
    region_state = {
        "candidate_bed": str(candidate_bed),
        "candidate_bed_name": candidate_bed.name,
        "region_label": region_label,
        "state": "pending",
    }
    if not candidate_has_regions(candidate_bed):
        region_state["state"] = "empty_candidate_region"
        region_states.append(region_state)
        continue

    callable_regions += 1
    outputs = {
        "proband": str(fragment_root / "proband" / f"trio_{safe_component(contract['proband_sample_id'])}_{safe_component(contig)}_{region_label}.vcf"),
        "father": str(fragment_root / "father" / f"trio_{safe_component(contract['father_sample_id'])}_{safe_component(contig)}_{region_label}.vcf"),
        "mother": str(fragment_root / "mother" / f"trio_{safe_component(contract['mother_sample_id'])}_{safe_component(contig)}_{region_label}.vcf"),
    }
    cmd = [
        "python",
        clair3_nova_script,
        "CallVarBam_Denovo",
        "--chkpnt_fn",
        model_checkpoint,
        "--bam_fn_c",
        os.environ["PROBAND_BAM"],
        "--bam_fn_p1",
        os.environ["FATHER_BAM"],
        "--bam_fn_p2",
        os.environ["MOTHER_BAM"],
        "--sampleName_c",
        contract["proband_sample_id"],
        "--sampleName_p1",
        contract["father_sample_id"],
        "--sampleName_p2",
        contract["mother_sample_id"],
        "--call_fn_c",
        outputs["proband"],
        "--call_fn_p1",
        outputs["father"],
        "--call_fn_p2",
        outputs["mother"],
        "--use_gpu",
        str(options["use_gpu"]),
        "--ref_fn",
        os.environ["REFERENCE_FASTA"],
        "--ctgName",
        str(contig),
        "--platform",
        options["platform"],
        "--full_aln_regions",
        str(candidate_bed),
        "--gvcf",
        str(bool(options["gvcf"])),
        "--showRef",
        str(bool(options["show_ref"])),
        "--tmp_path",
        "tmp",
        "--keep_iupac_bases",
        str(bool(options["keep_iupac_bases"])),
    ]
    if options["phasing_info_in_bam"]:
        cmd.append("--phasing_info_in_bam")

    command_record = {
        "contig": contig,
        "candidate_bed": str(candidate_bed),
        "outputs": outputs,
        "command": cmd,
    }
    commands.append(command_record)
    status = subprocess.run(cmd, check=False)
    missing_outputs = [role for role, path in outputs.items() if not Path(path).exists()]
    if status.returncode != 0 or missing_outputs:
        region_state.update(
            {
                "state": "failed_candidate_region" if status.returncode != 0 else "missing_denovo_outputs",
                "exit_code": status.returncode,
                "missing_outputs": missing_outputs,
                "outputs": outputs,
            }
        )
        failures.append(region_state)
    else:
        region_state.update({"state": "completed", "exit_code": 0, "outputs": outputs})
    region_states.append(region_state)

if failures:
    task_state = "failed_candidate_region"
elif callable_regions == 0 and candidate_files:
    task_state = "empty_candidate_regions"
elif callable_regions == 0:
    task_state = "no_candidate_regions"
else:
    task_state = "completed"

Path("trio_denovo_command.json").write_text(json.dumps(commands, indent=2, sort_keys=True) + "\\n")
state = {
    "schema": "wf-human-variation.trio_denovo_state.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "contig": contig,
    "state": task_state,
    "candidate_region_count": len(candidate_files),
    "callable_region_count": callable_regions,
    "failed_region_count": len(failures),
    "regions": region_states,
}
Path("trio_denovo_state.json").write_text(json.dumps(state, indent=2, sort_keys=True) + "\\n")

fragment_files = sorted(str(path) for path in fragment_root.rglob("*.vcf"))
manifest = {
    "schema": "wf-human-variation.trio_denovo_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "contig": contig,
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
    "role_sample_ids": {
        "proband": contract["proband_sample_id"],
        "father": contract["father_sample_id"],
        "mother": contract["mother_sample_id"],
    },
    "trio_candidate_beds": contract["trio_candidate_beds"],
    "trio_candidate_beds_digest": contract["trio_candidate_beds_digest"],
    "reference_fasta": contract["reference_fasta"],
    "clair3_nova_model_digest": contract["clair3_nova_model_digest"],
    "family_germline_config_digest": contract["family_germline_config_digest"],
    "container_digest": contract["container_digest"],
    "task_state": task_state,
    "candidate_region_count": len(candidate_files),
    "callable_region_count": callable_regions,
    "fragment_file_count": len(fragment_files),
    "outputs": {
        "trio_denovo_manifest": str(output_paths["trio_denovo_manifest"]),
        "trio_denovo_vcf_fragments": str(output_paths["trio_denovo_vcf_fragments"]),
        "trio_denovo_state": str(output_paths["trio_denovo_state"]),
        "trio_denovo_command_json": str(output_paths["trio_denovo_command_json"]),
    },
}
Path("trio_denovo_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.family_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "tool": "clair3-nova",
    "tool_operation": "CallVarBam_Denovo",
    "container_digest": contract["container_digest"],
    "command_arguments": commands,
    "input_checksums": {
        "trio_candidate_beds": contract["trio_candidate_beds_digest"],
        "proband_bam": contract["proband_bam_digest"],
        "proband_bam_index": contract["proband_bam_index_digest"],
        "father_bam": contract["father_bam_digest"],
        "father_bam_index": contract["father_bam_index_digest"],
        "mother_bam": contract["mother_bam_digest"],
        "mother_bam_index": contract["mother_bam_index_digest"],
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
    "schema": "wf-human-variation.trio_denovo_qc.v1",
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "task_key": contract["task_key"],
    "contig": contig,
    "state": task_state,
    "candidate_region_count": len(candidate_files),
    "callable_region_count": callable_regions,
    "fragment_file_count": len(fragment_files),
    "failed_region_count": len(failures),
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

copies = {
    "trio_denovo_manifest": Path("trio_denovo_manifest.json"),
    "trio_denovo_vcf_fragments": fragment_root,
    "trio_denovo_state": Path("trio_denovo_state.json"),
    "trio_denovo_command_json": Path("trio_denovo_command.json"),
    "family_provenance": Path("family_provenance.json"),
    "qc_stats": Path("qc_stats.json"),
}
for kind, source in copies.items():
    copy_output(source, output_paths[kind])

if failures:
    sys.exit(1)

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
        "contig": contig,
        "task_state": task_state,
        "candidate_region_count": len(candidate_files),
        "callable_region_count": callable_regions,
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
