process runBoundedFamilyMendelianAssessmentTask {
    label "wf_human_snp"
    tag "${entry.family_id}:${entry.analysis_intent_id}:${entry.reference_id}:${entry.task_key}"

    cpus { entry.family_mendelian_assessment_options.threads }
    memory 8.GB

    input:
        val entry
        val contract_json
        path family_joint_vcf
        path family_joint_vcf_index
        path family_sv_vcf
        path family_sv_vcf_index
        path reference_sdf
        path pedigree_snapshot

    output:
        path "family_rtg_snp_summary.txt", emit: family_rtg_snp_summary
        path "family_rtg_sv_summary.txt", emit: family_rtg_sv_summary
        path "mendelian_summary.json", emit: mendelian_summary
        path "mendelian_metrics.json", emit: mendelian_metrics
        path "family_mendelian_assessment_manifest.json", emit: family_mendelian_assessment_manifest
        path "family_mendelian_assessment_state.json", emit: family_mendelian_assessment_state
        path "family_provenance.json", emit: family_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-family-mendelian-assessment-contract.json <<'JSON'
${contract_json}
JSON

    export FAMILY_JOINT_VCF="${family_joint_vcf}"
    export FAMILY_JOINT_VCF_INDEX="${family_joint_vcf_index}"
    export FAMILY_SV_VCF="${family_sv_vcf}"
    export FAMILY_SV_VCF_INDEX="${family_sv_vcf_index}"
    export REFERENCE_SDF="${reference_sdf}"
    export PEDIGREE_SNAPSHOT="${pedigree_snapshot}"
    python3 - <<'PY'
import datetime
import json
import os
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


def load_pedigree_snapshot(path):
    text = path.read_text().strip()
    if not text:
        raise ValueError("pedigree snapshot is empty")
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return {"raw_ped_lines": [line for line in text.splitlines() if line.strip() and not line.startswith("#")]}
    return data


def pedigree_rows(snapshot, family_id):
    if isinstance(snapshot, dict) and snapshot.get("raw_ped_lines"):
        return [str(line) for line in snapshot["raw_ped_lines"]]
    memberships = snapshot.get("family_memberships") or snapshot.get("memberships") or []
    if isinstance(memberships, dict):
        memberships = memberships.values()
    role_samples = {}
    sex_by_sample = {}
    phenotype_by_sample = {}
    for membership in memberships:
        if not isinstance(membership, dict):
            continue
        if str(membership.get("family_id", family_id)) != family_id:
            continue
        role = str(membership.get("role", ""))
        sample_id = str(membership.get("sample_id", ""))
        if role and sample_id:
            role_samples[role] = sample_id
            sex_by_sample[sample_id] = str(membership.get("sex", "0"))
            phenotype_by_sample[sample_id] = str(membership.get("phenotype", "0"))
    proband = role_samples.get("proband")
    if not proband:
        raise ValueError("pedigree snapshot does not contain an active proband")
    father = role_samples.get("father", "0")
    mother = role_samples.get("mother", "0")
    rows = [
        "\\t".join([
            family_id,
            proband,
            father,
            mother,
            _ped_sex(sex_by_sample.get(proband, "0")),
            _ped_phenotype(phenotype_by_sample.get(proband, "0")),
        ])
    ]
    for role in ("father", "mother"):
        sample_id = role_samples.get(role)
        if not sample_id:
            continue
        rows.append(
            "\\t".join([
                family_id,
                sample_id,
                "0",
                "0",
                _ped_sex(sex_by_sample.get(sample_id, "0")),
                _ped_phenotype(phenotype_by_sample.get(sample_id, "0")),
            ])
        )
    return rows


def _ped_sex(value):
    normalized = str(value).lower()
    return {"male": "1", "father": "1", "1": "1", "female": "2", "mother": "2", "2": "2"}.get(normalized, "0")


def _ped_phenotype(value):
    normalized = str(value).lower()
    return {"affected": "2", "2": "2", "unaffected": "1", "1": "1"}.get(normalized, "0")


def summarize_rtg_output(kind, result, output_dir):
    files = sorted(path for path in output_dir.rglob("*") if path.is_file()) if output_dir.exists() else []
    text_fragments = []
    for path in files:
        if path.suffix.lower() in {".txt", ".tsv", ".log"} or path.name.lower() in {"summary", "summary.txt"}:
            try:
                text = path.read_text(errors="replace").strip()
            except OSError:
                text = ""
            if text:
                text_fragments.append(f"## {path.relative_to(output_dir)}\\n{text}")
    summary = {
        "variant_class": kind,
        "exit_code": result.returncode,
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip(),
        "output_files": [str(path.relative_to(output_dir)) for path in files],
    }
    if text_fragments:
        summary["text"] = "\\n\\n".join(text_fragments)
    return summary


contract = json.loads(Path("bounded-family-mendelian-assessment-contract.json").read_text())
options = contract["family_mendelian_assessment_options"]
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
selected_classes = [str(item) for item in options["variant_classes"]]
commands = {}
executed = []
results = {}
failure = None

snapshot = load_pedigree_snapshot(Path(os.environ["PEDIGREE_SNAPSHOT"]))
rows = pedigree_rows(snapshot, contract["family_id"])
Path("family.ped").write_text("\\n".join(rows) + "\\n")

rtg_version = "unknown"
version = run_command(["rtg", "version"], executed)
if version.returncode == 0 and version.stdout.strip():
    rtg_version = version.stdout.strip().splitlines()[0]

java_version = "unknown"
java = run_command(["java", "-version"], executed)
if java.returncode == 0:
    java_version = (java.stderr or java.stdout).strip().splitlines()[0]

input_vcfs = {
    "snp": {
        "vcf": Path(os.environ["FAMILY_JOINT_VCF"]),
        "index": Path(os.environ["FAMILY_JOINT_VCF_INDEX"]),
        "digest": contract.get("family_joint_vcf_digest", ""),
    },
    "sv": {
        "vcf": Path(os.environ["FAMILY_SV_VCF"]),
        "index": Path(os.environ["FAMILY_SV_VCF_INDEX"]),
        "digest": contract.get("family_sv_vcf_digest", ""),
    },
}

for variant_class in selected_classes:
    source = input_vcfs[variant_class]
    if not source["vcf"].exists():
        raise FileNotFoundError(f"{variant_class} family VCF does not exist: {source['vcf']}")
    if not source["index"].exists():
        raise FileNotFoundError(f"{variant_class} family VCF index does not exist: {source['index']}")
    work_dir = Path(f"rtg_{variant_class}")
    cmd = [
        "rtg",
        "mendelian",
        "-i",
        str(source["vcf"]),
        "-t",
        os.environ["REFERENCE_SDF"],
        "--pedigree",
        "family.ped",
        "-o",
        str(work_dir),
    ]
    commands[f"rtg_mendelian_{variant_class}"] = cmd
    result = run_command(cmd, executed)
    results[variant_class] = summarize_rtg_output(variant_class, result, work_dir)
    if result.returncode != 0:
        failure = {
            "stage": f"rtg_mendelian_{variant_class}",
            "exit_code": result.returncode,
            "stderr": result.stderr,
        }
        break

for variant_class in ("snp", "sv"):
    summary_path = Path(f"family_rtg_{variant_class}_summary.txt")
    if variant_class in results:
        payload = results[variant_class]
        lines = [
            f"variant_class\\t{variant_class}",
            f"exit_code\\t{payload['exit_code']}",
            f"output_files\\t{','.join(payload['output_files'])}",
        ]
        if payload.get("stdout"):
            lines.append(f"stdout\\t{payload['stdout']}")
        if payload.get("stderr"):
            lines.append(f"stderr\\t{payload['stderr']}")
        if payload.get("text"):
            lines.extend(["", str(payload["text"])])
        summary_path.write_text("\\n".join(lines) + "\\n")
    else:
        summary_path.write_text(f"variant_class\\t{variant_class}\\nstate\\tskipped_not_requested\\n")

state_value = "failed" if failure else ("completed" if set(selected_classes) == {"snp", "sv"} else "completed_subset")
summary = {
    "schema": "wf-human-variation.mendelian_summary.v1",
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "variant_classes": selected_classes,
    "state": state_value,
    "results": results,
    "failure": failure,
}
Path("mendelian_summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\\n")

metrics = {
    "schema": "wf-human-variation.mendelian_metrics.v1",
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "assessed_variant_classes": selected_classes,
    "completed_variant_classes": sorted(results),
    "failed": failure is not None,
    "state": state_value,
}
Path("mendelian_metrics.json").write_text(json.dumps(metrics, indent=2, sort_keys=True) + "\\n")

Path("family_mendelian_assessment_state.json").write_text(json.dumps({
    "schema": "wf-human-variation.family_mendelian_assessment_state.v1",
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "state": state_value,
    "variant_classes": selected_classes,
    "failure": failure,
}, indent=2, sort_keys=True) + "\\n")

manifest = {
    "schema": "wf-human-variation.family_mendelian_assessment_manifest.v1",
    "created_at_utc": utc_now(),
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
    "pedigree_snapshot_digest": contract["pedigree_snapshot_digest"],
    "reference_digest": contract["reference_digest"],
    "rtg_config_digest": contract["rtg_config_digest"],
    "container_digest": contract["container_digest"],
    "variant_classes": selected_classes,
    "input_vcf_digests": {
        "snp": contract.get("family_joint_vcf_digest", ""),
        "sv": contract.get("family_sv_vcf_digest", ""),
    },
    "commands": commands,
    "outputs": {key: str(value) for key, value in output_paths.items()},
}
Path("family_mendelian_assessment_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.family_provenance.v1",
    "task_family": "family_mendelian_assessment",
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "tool_versions": {
        "rtg": rtg_version,
        "java": java_version,
    },
    "container_digest": contract["container_digest"],
    "input_digests": {
        "pedigree_snapshot": contract["pedigree_snapshot_digest"],
        "reference": contract["reference_digest"],
        "family_joint_vcf": contract.get("family_joint_vcf_digest", ""),
        "family_sv_vcf": contract.get("family_sv_vcf_digest", ""),
        "rtg_config": contract["rtg_config_digest"],
    },
    "commands": commands,
    "executed_commands": executed,
}
Path("family_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.mendelian_assessment_qc.v1",
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "state": state_value,
    "assessed_variant_classes": selected_classes,
    "rtg_exit_codes": {key: value["exit_code"] for key, value in results.items()},
    "html_report": {"requested": False, "produced": False},
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

copies = {
    "family_rtg_snp_summary": Path("family_rtg_snp_summary.txt"),
    "family_rtg_sv_summary": Path("family_rtg_sv_summary.txt"),
    "mendelian_summary": Path("mendelian_summary.json"),
    "mendelian_metrics": Path("mendelian_metrics.json"),
    "family_mendelian_assessment_manifest": Path("family_mendelian_assessment_manifest.json"),
    "family_mendelian_assessment_state": Path("family_mendelian_assessment_state.json"),
    "family_provenance": Path("family_provenance.json"),
    "qc_stats": Path("qc_stats.json"),
}
for key, source in copies.items():
    copy_output(source, output_paths[key])

if failure:
    raise SystemExit(f"RTG Mendelian assessment failed: {failure}")

Path(contract["completion_marker_path"]).parent.mkdir(parents=True, exist_ok=True)
Path(contract["completion_marker_path"]).write_text(json.dumps({
    "marker_schema": "gnostikon.task_completion.v1",
    "task_key": contract["task_key"],
    "task_family": contract["task_family"],
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "state": state_value,
    "variant_classes": selected_classes,
    "created_at_utc": utc_now(),
}, indent=2, sort_keys=True) + "\\n")
PY
    """
}
