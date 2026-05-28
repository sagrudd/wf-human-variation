process runBoundedSomaticAnnotationTask {
    label "snpeff_annotation"
    tag "${entry.analysis_intent_id}:${entry.annotation_mode}:${entry.reference_id}:${entry.source_output_artefact_id}"

    cpus { entry.somatic_annotation_options.threads }
    memory 6.GB

    input:
        val entry
        val contract_json
        path source_vcf
        path source_vcf_index
        path snpeff_database
        path clinvar_vcf
        path clinvar_vcf_index
        path sift_annotation

    output:
        path "somatic_annotated.vcf.gz", emit: somatic_annotated_vcf
        path "somatic_annotated.vcf.gz.tbi", emit: somatic_annotated_vcf_index
        path "somatic_clinvar.vcf.gz", emit: somatic_clinvar_vcf
        path "somatic_clinvar.vcf.gz.tbi", emit: somatic_clinvar_vcf_index
        path "somatic_annotation_manifest.json", emit: somatic_annotation_manifest
        path "somatic_annotation_command.json", emit: somatic_annotation_command_json
        path "somatic_provenance.json", emit: somatic_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-somatic-annotation-contract.json <<'JSON'
${contract_json}
JSON

    export SOURCE_VCF="${source_vcf}"
    export SOURCE_VCF_INDEX="${source_vcf_index}"
    export SNPEFF_DATABASE="${snpeff_database}"
    export STAGED_CLINVAR_VCF="${clinvar_vcf}"
    export STAGED_CLINVAR_VCF_INDEX="${clinvar_vcf_index}"
    export STAGED_SIFT_ANNOTATION="${sift_annotation}"
    python3 - <<'PY'
import json
import os
import shlex
import subprocess
from pathlib import Path


def staged_optional(contract, name, staged_env):
    value = contract.get(name) or ""
    if not value:
        return ""
    staged = Path(os.environ[staged_env])
    if not staged.exists():
        raise FileNotFoundError(f"{name} was declared but was not staged in the work directory: {staged}")
    return str(staged)


contract = json.loads(Path("bounded-somatic-annotation-contract.json").read_text())
if contract["reference_genome_build"] not in {"hg19", "hg38"}:
    raise ValueError("somatic annotation requires validated hg19 or hg38 reference_genome_build")

source_vcf = os.environ["SOURCE_VCF"]
snpeff_database = Path(os.environ["SNPEFF_DATABASE"])
snpeff_database_name = contract["snpeff_database_name"]
clinvar = staged_optional(contract, "clinvar_vcf", "STAGED_CLINVAR_VCF")
sift_annotation = staged_optional(contract, "sift_annotation", "STAGED_SIFT_ANNOTATION")
options = contract["somatic_annotation_options"]

command = [
    "snpEff",
    "-XX:ActiveProcessorCount=" + str(options["threads"]),
    "ann",
    "-noStats",
    "-noLog",
    "-dataDir",
    str(snpeff_database.parent),
    snpeff_database_name,
    source_vcf,
]
Path("run-snpeff.command.sh").write_text(" ".join(shlex.quote(part) for part in command) + " > somatic.snpeff.vcf\\n")
subprocess.run(["bash", "run-snpeff.command.sh"], check=True)

if clinvar:
    annotate_command = [
        "SnpSift",
        "-XX:ActiveProcessorCount=" + str(options["threads"]),
        "annotate",
        clinvar,
        "somatic.snpeff.vcf",
    ]
    Path("run-snpsift-annotate.command.sh").write_text(
        " ".join(shlex.quote(part) for part in annotate_command) + " | bgzip -c > somatic_annotated.vcf.gz\\n"
    )
    subprocess.run(["bash", "run-snpsift-annotate.command.sh"], check=True)
else:
    annotate_command = []
    subprocess.run(["bash", "-lc", "bgzip -c somatic.snpeff.vcf > somatic_annotated.vcf.gz"], check=True)
subprocess.run(["tabix", "-p", "vcf", "somatic_annotated.vcf.gz"], check=True)

filter_expression = options["clinvar_filter_expression"]
if clinvar:
    Path("run-snpsift-filter.command.sh").write_text(
        "bcftools view somatic_annotated.vcf.gz | "
        + "SnpSift filter "
        + shlex.quote(filter_expression)
        + " | bgzip -c > somatic_clinvar.vcf.gz\\n"
    )
    subprocess.run(["bash", "run-snpsift-filter.command.sh"], check=True)
else:
    Path("run-snpsift-filter.command.sh").write_text("# ClinVar asset not provided; creating header-only VCF\\n")
    subprocess.run(["bash", "-lc", "bcftools view -h somatic_annotated.vcf.gz | bgzip -c > somatic_clinvar.vcf.gz"], check=True)
subprocess.run(["tabix", "-p", "vcf", "somatic_clinvar.vcf.gz"], check=True)

command_metadata = {
    "schema": "wf-human-variation.somatic_annotation_command.v1",
    "task_key": contract["task_key"],
    "annotation_mode": contract["annotation_mode"],
    "tools": ["snpEff", "SnpSift", "bcftools", "bgzip", "tabix"],
    "snpeff": command,
    "snpsift_annotate": annotate_command,
    "clinvar_filter_expression": filter_expression,
    "optional_inputs": {
        "clinvar_vcf": clinvar or None,
        "sift_annotation": sift_annotation or None,
    },
}
Path("somatic_annotation_command.json").write_text(json.dumps(command_metadata, indent=2, sort_keys=True) + "\\n")
PY

    python3 - <<'PY'
import datetime
import json
import shutil
from pathlib import Path


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


def copy_output(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


contract = json.loads(Path("bounded-somatic-annotation-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
command_metadata = json.loads(Path("somatic_annotation_command.json").read_text())
optional_inputs = {
    "clinvar_vcf": {
        "path": contract["clinvar_vcf"] or None,
        "digest": contract["clinvar_vcf_digest"] or None,
        "state": "provided" if contract["clinvar_vcf"] else "optional_not_provided",
    },
    "sift_annotation": {
        "path": contract["sift_annotation"] or None,
        "digest": contract["sift_annotation_digest"] or None,
        "state": "provided" if contract["sift_annotation"] else "optional_not_provided",
    },
}

manifest = {
    "schema": "wf-human-variation.somatic_annotation_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "source_output_artefact_id": contract["source_output_artefact_id"],
    "annotation_mode": contract["annotation_mode"],
    "reference_id": contract["reference_id"],
    "reference_genome_build": contract["reference_genome_build"],
    "snpeff_database_name": contract["snpeff_database_name"],
    "snpeff_database_digest": contract["snpeff_database_digest"],
    "annotation_config_digest": contract["annotation_config_digest"],
    "container_digest": contract["container_digest"],
    "optional_inputs": optional_inputs,
    "outputs": {
        "somatic_annotated_vcf": str(output_paths["somatic_annotated_vcf"]),
        "somatic_annotated_vcf_index": str(output_paths["somatic_annotated_vcf_index"]),
        "somatic_clinvar_vcf": str(output_paths["somatic_clinvar_vcf"]),
        "somatic_clinvar_vcf_index": str(output_paths["somatic_clinvar_vcf_index"]),
        "somatic_annotation_manifest": str(output_paths["somatic_annotation_manifest"]),
        "somatic_annotation_command_json": str(output_paths["somatic_annotation_command_json"]),
    },
    "removed_products": {
        "html_report": {"available": False, "reason": "removed_from_humvar3_contract"},
        "caller_side_effect": {"available": False, "reason": "annotation_is_bounded_task"},
    },
}
Path("somatic_annotation_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.somatic_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "tool": "snpeff_snpsift",
    "container_digest": contract["container_digest"],
    "command_arguments": command_metadata,
    "input_checksums": {
        "source_vcf": contract["source_vcf_digest"],
        "source_vcf_index": contract["source_vcf_index_digest"],
        "snpeff_database": contract["snpeff_database_digest"],
        "clinvar_vcf": contract["clinvar_vcf_digest"] or None,
        "sift_annotation": contract["sift_annotation_digest"] or None,
        "annotation_config": contract["annotation_config_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
}
Path("somatic_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.somatic_annotation_qc.v1",
    "analysis_intent_id": contract["analysis_intent_id"],
    "annotation_mode": contract["annotation_mode"],
    "source_output_artefact_id": contract["source_output_artefact_id"],
    "somatic_annotated_vcf": str(output_paths["somatic_annotated_vcf"]),
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

for kind, source in {
    "somatic_annotated_vcf": Path("somatic_annotated.vcf.gz"),
    "somatic_annotated_vcf_index": Path("somatic_annotated.vcf.gz.tbi"),
    "somatic_clinvar_vcf": Path("somatic_clinvar.vcf.gz"),
    "somatic_clinvar_vcf_index": Path("somatic_clinvar.vcf.gz.tbi"),
    "somatic_annotation_manifest": Path("somatic_annotation_manifest.json"),
    "somatic_annotation_command_json": Path("somatic_annotation_command.json"),
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
        "annotation_mode": contract["annotation_mode"],
        "source_output_artefact_id": contract["source_output_artefact_id"],
        "reference_id": contract["reference_id"],
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
