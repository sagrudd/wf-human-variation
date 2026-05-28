process runBoundedSomaticPairedSnvCandidateTask {
    label "somatic_clairs"
    tag "${entry.analysis_intent_id}:${entry.pair_id}:${entry.contig}:${entry.task_key}"

    cpus { entry.clairs_options.threads }
    memory { 6.GB * task.attempt }
    maxRetries 1
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }

    input:
        val entry
        val contract_json
        path tumour_aggregate_xam
        path tumour_aggregate_xam_index
        path normal_or_control_aggregate_xam
        path normal_or_control_aggregate_xam_index
        path normal_vcf
        path normal_vcf_index
        path shared_region_bed
        path reference
        path reference_index
        path clairs_model
        path clairs_reference_bundle
        path target_bed
        path genotyping_vcf
        path genotyping_vcf_index

    output:
        path "somatic_candidate_snv", emit: somatic_candidate_snv
        path "somatic_candidate_indel", emit: somatic_candidate_indel
        path "somatic_candidate_hybrid", emit: somatic_candidate_hybrid
        path "somatic_candidate_bed", emit: somatic_candidate_bed
        path "somatic_paired_snv_candidate_manifest.json", emit: somatic_paired_snv_candidate_manifest
        path "somatic_paired_snv_candidate_command.json", emit: somatic_paired_snv_candidate_command_json
        path "somatic_paired_snv_candidate.log", emit: somatic_paired_snv_candidate_logs
        path "somatic_provenance.json", emit: somatic_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-somatic-paired-snv-candidate-contract.json <<'JSON'
${contract_json}
JSON

    export TUMOUR_XAM="${tumour_aggregate_xam}"
    export NORMAL_OR_CONTROL_XAM="${normal_or_control_aggregate_xam}"
    export NORMAL_VCF="${normal_vcf}"
    export SHARED_REGION_BED="${shared_region_bed}"
    export REFERENCE_FASTA="${reference}"
    export CLAIRS_MODEL="${clairs_model}"
    export CLAIRS_REFERENCE_BUNDLE="${clairs_reference_bundle}"
    export TARGET_BED="${target_bed}"
    export GENOTYPING_VCF="${genotyping_vcf}"
    python3 - <<'PY'
import json
import os
import shlex
import subprocess
from pathlib import Path


def optional_stage(name, env_name):
    declared = contract.get(name) or ""
    staged = os.environ.get(env_name, "")
    if not declared:
        return ""
    if not staged or not Path(staged).exists():
        raise FileNotFoundError(f"{name} was declared but was not staged: {declared}")
    return staged


contract = json.loads(Path("bounded-somatic-paired-snv-candidate-contract.json").read_text())
options = contract["clairs_options"]
clairs_path = os.environ.get("CLAIRS_PATH", "").strip()
if not clairs_path:
    raise EnvironmentError("CLAIRS_PATH must be set by the ClairS runtime container")
model_path = Path(os.environ["CLAIRS_MODEL"])
model_name = contract.get("clairs_model_name") or model_path.name
target_bed = optional_stage("target_bed", "TARGET_BED")
genotyping_vcf = optional_stage("genotyping_vcf", "GENOTYPING_VCF")
chunk_id = str(contract["chunk_id"])
total_chunks = str(contract["total_chunks"])
contig = str(contract["contig"])

command = [
    "pypy3",
    str(Path(clairs_path) / "clairs.py"),
    "extract_pair_candidates",
    "--tumor_bam_fn", os.environ["TUMOUR_XAM"],
    "--normal_bam_fn", os.environ["NORMAL_OR_CONTROL_XAM"],
    "--ref_fn", os.environ["REFERENCE_FASTA"],
    "--samtools", "samtools",
    "--snv_min_af", str(options["min_af"]),
    "--indel_min_af", str(options["indel_min_af"]),
    "--chunk_id", chunk_id,
    "--chunk_num", total_chunks,
    "--ctg_name", contig,
    "--platform", options["platform"],
    "--min_coverage", str(options["min_coverage"]),
    "--bed_fn", os.environ["SHARED_REGION_BED"],
    "--candidates_folder", "candidates/",
    "--select_indel_candidates", "True",
    "--output_depth", "True",
]
if options["min_bq"]:
    command.extend(["--min_bq", str(options["min_bq"])])
if genotyping_vcf:
    command.extend(["--genotyping_mode_vcf_fn", genotyping_vcf])

command_metadata = {
    "schema": "wf-human-variation.somatic_paired_snv_candidate_command.v1",
    "task_key": contract["task_key"],
    "tool": "clairs",
    "stage": "extract_pair_candidates",
    "extract_pair_candidates": command,
    "structured_options": options,
    "region": {
        "region_id": contract["region_id"],
        "contig": contig,
        "chunk_id": chunk_id,
        "total_chunks": total_chunks,
    },
    "optional_inputs": {
        "target_bed": target_bed or None,
        "genotyping_vcf": genotyping_vcf or None,
    },
    "environment": {
        "CLAIRS_PATH": clairs_path,
        "CLAIR_MODELS_PATH": str(model_path.parent),
        "CLAIRS_REFERENCE_BUNDLE": os.environ["CLAIRS_REFERENCE_BUNDLE"],
    },
}
Path("somatic_paired_snv_candidate_command.json").write_text(json.dumps(command_metadata, indent=2, sort_keys=True) + "\\n")
Path("run-clairs-candidate.command.sh").write_text(" ".join(shlex.quote(part) for part in command) + "\\n")

Path("candidates").mkdir(exist_ok=True)
Path("indels").mkdir(exist_ok=True)
Path("hybrid").mkdir(exist_ok=True)
with Path("somatic_paired_snv_candidate.log").open("w") as log:
    subprocess.run(["bash", "run-clairs-candidate.command.sh"], check=True, stdout=log, stderr=subprocess.STDOUT)

for path in sorted(Path("candidates").glob("INDEL_*")) + sorted(Path("candidates").glob("*_indel")):
    path.replace(Path("indels") / path.name)
for path in sorted(Path("candidates").glob("*_hybrid_info")):
    path.replace(Path("hybrid") / path.name)
PY

    python3 - <<'PY'
import datetime
import json
import shutil
from pathlib import Path


def copy_output(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.is_dir():
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(source, target)
    else:
        shutil.copy2(source, target)


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


contract = json.loads(Path("bounded-somatic-paired-snv-candidate-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
Path("somatic_candidate_snv").mkdir(exist_ok=True)
Path("somatic_candidate_indel").mkdir(exist_ok=True)
Path("somatic_candidate_hybrid").mkdir(exist_ok=True)
Path("somatic_candidate_bed").mkdir(exist_ok=True)
for source, target_name in (
    (Path("candidates"), "somatic_candidate_snv"),
    (Path("indels"), "somatic_candidate_indel"),
    (Path("hybrid"), "somatic_candidate_hybrid"),
    (Path("candidates") / "bed", "somatic_candidate_bed"),
):
    if source.exists():
        copy_output(source, Path(target_name))

command_metadata = json.loads(Path("somatic_paired_snv_candidate_command.json").read_text())
manifest = {
    "schema": "wf-human-variation.somatic_paired_snv_candidate_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "paired_role": contract["paired_role"],
    "tumour_sample_id": contract["tumour_sample_id"],
    "normal_or_control_sample_id": contract["normal_or_control_sample_id"],
    "reference_id": contract["reference_id"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
    "region": command_metadata["region"],
    "clairs_model": contract["clairs_model"],
    "clairs_model_name": contract["clairs_model_name"] or Path(contract["clairs_model"]).name,
    "clairs_model_digest": contract["clairs_model_digest"],
    "clairs_model_table_digest": contract["clairs_model_table_digest"],
    "clairs_reference_bundle_digest": contract["clairs_reference_bundle_digest"],
    "clairs_config_digest": contract["clairs_config_digest"],
    "clairs_options_digest": contract["clairs_options_digest"],
    "container_digest": contract["container_digest"],
    "outputs": {key: str(value) for key, value in output_paths.items()},
}
Path("somatic_paired_snv_candidate_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.somatic_provenance.v1",
    "task_family": contract["task_family"],
    "task_stage": "paired_candidate_extraction",
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "tool": "clairs",
    "container_digest": contract["container_digest"],
    "command_arguments": command_metadata,
    "input_checksums": {
        "tumour_aggregate_xam": contract["tumour_aggregate_xam_digest"],
        "tumour_aggregate_xam_index": contract["tumour_aggregate_xam_index_digest"],
        "normal_or_control_aggregate_xam": contract["normal_or_control_aggregate_xam_digest"],
        "normal_or_control_aggregate_xam_index": contract["normal_or_control_aggregate_xam_index_digest"],
        "normal_vcf": contract["normal_vcf_digest"],
        "normal_vcf_index": contract["normal_vcf_index_digest"],
        "shared_region_bed": contract["shared_region_bed_digest"],
        "reference": contract["reference_digest"],
        "clairs_model": contract["clairs_model_digest"],
        "clairs_model_table": contract["clairs_model_table_digest"],
        "clairs_reference_bundle": contract["clairs_reference_bundle_digest"],
        "clairs_config": contract["clairs_config_digest"],
        "clairs_options": contract["clairs_options_digest"],
        "target_bed": contract["target_bed_digest"] or None,
        "genotyping_vcf": contract["genotyping_vcf_digest"] or None,
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
}
Path("somatic_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.somatic_paired_snv_candidate_qc.v1",
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "region": command_metadata["region"],
    "candidate_file_counts": {
        "snv": len(list(Path("somatic_candidate_snv").rglob("*"))),
        "indel": len(list(Path("somatic_candidate_indel").rglob("*"))),
        "hybrid": len(list(Path("somatic_candidate_hybrid").rglob("*"))),
        "bed": len(list(Path("somatic_candidate_bed").rglob("*"))),
    },
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

for kind, source in {
    "somatic_candidate_snv": Path("somatic_candidate_snv"),
    "somatic_candidate_indel": Path("somatic_candidate_indel"),
    "somatic_candidate_hybrid": Path("somatic_candidate_hybrid"),
    "somatic_candidate_bed": Path("somatic_candidate_bed"),
    "somatic_paired_snv_candidate_manifest": Path("somatic_paired_snv_candidate_manifest.json"),
    "somatic_paired_snv_candidate_command_json": Path("somatic_paired_snv_candidate_command.json"),
    "somatic_paired_snv_candidate_logs": Path("somatic_paired_snv_candidate.log"),
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
    "outputs": [{"kind": kind, "path": str(output_paths[kind]), "required": True} for kind in sorted(output_paths)],
    "metadata": {
        "bounded_entry": contract["entry_name"],
        "entry_schema": contract["entry_schema"],
        "analysis_intent_id": contract["analysis_intent_id"],
        "pair_id": contract["pair_id"],
        "region_id": contract["region_id"],
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}


process runBoundedSomaticPairedSnvPileupTask {
    label "somatic_clairs"
    tag "${entry.analysis_intent_id}:${entry.pair_id}:${entry.region_id}:${entry.variant_type}:${entry.task_key}"

    cpus { entry.clairs_options.threads }
    memory { 4.GB * task.attempt }
    maxRetries 3
    errorStrategy { task.exitStatus in [134, 137, 140] ? 'retry' : 'finish' }

    input:
        val entry
        val contract_json
        path tumour_aggregate_xam
        path tumour_aggregate_xam_index
        path normal_or_control_aggregate_xam
        path normal_or_control_aggregate_xam_index
        path candidate_bed
        path candidate_variants
        path reference
        path reference_index
        path clairs_model

    output:
        path "somatic_pileup_prediction_fragments", emit: somatic_pileup_prediction_fragments
        path "somatic_pileup_prediction_manifest.json", emit: somatic_pileup_prediction_manifest
        path "somatic_pileup_prediction_command.json", emit: somatic_pileup_prediction_command_json
        path "somatic_paired_snv_pileup.log", emit: somatic_paired_snv_pileup_logs
        path "somatic_provenance.json", emit: somatic_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-somatic-paired-snv-pileup-contract.json <<'JSON'
${contract_json}
JSON

    export TUMOUR_XAM="${tumour_aggregate_xam}"
    export NORMAL_OR_CONTROL_XAM="${normal_or_control_aggregate_xam}"
    export CANDIDATE_BED="${candidate_bed}"
    export CANDIDATE_VARIANTS="${candidate_variants}"
    export REFERENCE_FASTA="${reference}"
    export CLAIRS_MODEL="${clairs_model}"
    python3 - <<'PY'
import json
import os
import shlex
import subprocess
from pathlib import Path

contract = json.loads(Path("bounded-somatic-paired-snv-pileup-contract.json").read_text())
options = contract["clairs_options"]
clairs_path = os.environ.get("CLAIRS_PATH", "").strip()
if not clairs_path:
    raise EnvironmentError("CLAIRS_PATH must be set by the ClairS runtime container")
model_path = Path(os.environ["CLAIRS_MODEL"])
model_name = contract.get("clairs_model_name") or model_path.name
region_id = str(contract["region_id"])
variant_type = str(contract["variant_type"])
contig = str(contract["contig"])
tensor_dir = Path("pileup_tensor_can")
fragment_dir = Path("somatic_pileup_prediction_fragments")
tensor_dir.mkdir(exist_ok=True)
fragment_dir.mkdir(exist_ok=True)
tensor_path = tensor_dir / f"{region_id}.{variant_type}.tensor"
vcf_prefix = "indel_p" if variant_type == "indel" else "p"
vcf_path = fragment_dir / f"{vcf_prefix}_{region_id}.vcf"
checkpoint = model_path / ("indel/pileup.pkl" if variant_type == "indel" else "pileup.pkl")

create_tensor = [
    "pypy3",
    str(Path(clairs_path) / "clairs.py"),
    "create_pair_tensor_pileup",
    "--normal_bam_fn", os.environ["NORMAL_OR_CONTROL_XAM"],
    "--tumor_bam_fn", os.environ["TUMOUR_XAM"],
    "--ref_fn", os.environ["REFERENCE_FASTA"],
    "--samtools", "samtools",
    "--ctg_name", contig,
    "--candidates_bed_regions", os.environ["CANDIDATE_BED"],
    "--tensor_can_fn", str(tensor_path),
    "--platform", options["platform"],
]
if options["min_bq"]:
    create_tensor.extend(["--min_bq", str(options["min_bq"])])

predict = [
    "python3",
    str(Path(clairs_path) / "clairs.py"),
    "predict",
    "--tensor_fn", str(tensor_path),
    "--call_fn", str(vcf_path),
    "--chkpnt_fn", str(checkpoint),
    "--platform", options["platform"],
    "--use_gpu", "False",
    "--ctg_name", contig,
    "--pileup",
    "--enable_indel_calling", "True" if variant_type == "indel" else "False",
]

command_metadata = {
    "schema": "wf-human-variation.somatic_paired_snv_pileup_command.v1",
    "task_key": contract["task_key"],
    "tool": "clairs",
    "stage": "paired_pileup_tensor_prediction",
    "create_pair_tensor_pileup": create_tensor,
    "predict": predict,
    "structured_options": options,
    "region": {
        "region_id": region_id,
        "contig": contig,
        "variant_type": variant_type,
    },
    "candidate_inputs": {
        "candidate_bed": contract["candidate_bed"],
        "candidate_variants": contract["candidate_variants"],
    },
    "model": {
        "path": contract["clairs_model"],
        "name": model_name,
        "checkpoint": str(checkpoint),
    },
}
Path("somatic_pileup_prediction_command.json").write_text(json.dumps(command_metadata, indent=2, sort_keys=True) + "\\n")
Path("run-clairs-pileup.command.sh").write_text(
    " ".join(shlex.quote(part) for part in create_tensor) + "\\n" +
    " ".join(shlex.quote(part) for part in predict) + "\\n"
)

with Path("somatic_paired_snv_pileup.log").open("w") as log:
    subprocess.run(["bash", "run-clairs-pileup.command.sh"], check=True, stdout=log, stderr=subprocess.STDOUT)
PY

    python3 - <<'PY'
import datetime
import json
import shutil
from pathlib import Path


def copy_output(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.is_dir():
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(source, target)
    else:
        shutil.copy2(source, target)


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


contract = json.loads(Path("bounded-somatic-paired-snv-pileup-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
command_metadata = json.loads(Path("somatic_pileup_prediction_command.json").read_text())
fragment_files = sorted(str(path) for path in Path("somatic_pileup_prediction_fragments").glob("*.vcf"))
manifest = {
    "schema": "wf-human-variation.somatic_pileup_prediction_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "paired_role": contract["paired_role"],
    "tumour_sample_id": contract["tumour_sample_id"],
    "normal_or_control_sample_id": contract["normal_or_control_sample_id"],
    "reference_id": contract["reference_id"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
    "region": command_metadata["region"],
    "clairs_model": contract["clairs_model"],
    "clairs_model_name": contract["clairs_model_name"] or Path(contract["clairs_model"]).name,
    "clairs_model_digest": contract["clairs_model_digest"],
    "clairs_model_table_digest": contract["clairs_model_table_digest"],
    "clairs_config_digest": contract["clairs_config_digest"],
    "clairs_options_digest": contract["clairs_options_digest"],
    "container_digest": contract["container_digest"],
    "fragment_files": fragment_files,
    "outputs": {key: str(value) for key, value in output_paths.items()},
}
Path("somatic_pileup_prediction_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.somatic_provenance.v1",
    "task_family": contract["task_family"],
    "task_stage": "paired_pileup_tensor_prediction",
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "tool": "clairs",
    "container_digest": contract["container_digest"],
    "command_arguments": command_metadata,
    "input_checksums": {
        "tumour_aggregate_xam": contract["tumour_aggregate_xam_digest"],
        "tumour_aggregate_xam_index": contract["tumour_aggregate_xam_index_digest"],
        "normal_or_control_aggregate_xam": contract["normal_or_control_aggregate_xam_digest"],
        "normal_or_control_aggregate_xam_index": contract["normal_or_control_aggregate_xam_index_digest"],
        "candidate_bed": contract["candidate_bed_digest"],
        "candidate_variants": contract["candidate_variants_digest"],
        "reference": contract["reference_digest"],
        "clairs_model": contract["clairs_model_digest"],
        "clairs_model_table": contract["clairs_model_table_digest"],
        "clairs_config": contract["clairs_config_digest"],
        "clairs_options": contract["clairs_options_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
}
Path("somatic_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.somatic_pileup_prediction_qc.v1",
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "region": command_metadata["region"],
    "fragment_count": len(fragment_files),
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

for kind, source in {
    "somatic_pileup_prediction_fragments": Path("somatic_pileup_prediction_fragments"),
    "somatic_pileup_prediction_manifest": Path("somatic_pileup_prediction_manifest.json"),
    "somatic_pileup_prediction_command_json": Path("somatic_pileup_prediction_command.json"),
    "somatic_paired_snv_pileup_logs": Path("somatic_paired_snv_pileup.log"),
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
    "outputs": [{"kind": kind, "path": str(output_paths[kind]), "required": True} for kind in sorted(output_paths)],
    "metadata": {
        "bounded_entry": contract["entry_name"],
        "entry_schema": contract["entry_schema"],
        "analysis_intent_id": contract["analysis_intent_id"],
        "pair_id": contract["pair_id"],
        "region_id": contract["region_id"],
        "variant_type": contract["variant_type"],
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}


process runBoundedSomaticPairedSnvFullAlignmentTask {
    label "somatic_clairs"
    tag "${entry.analysis_intent_id}:${entry.pair_id}:${entry.region_id}:${entry.variant_type}:${entry.task_key}"

    cpus { entry.clairs_options.threads }
    memory { 4.GB * task.attempt }
    maxRetries 3
    errorStrategy { task.exitStatus in [134, 137, 140] ? 'retry' : 'finish' }

    input:
        val entry
        val contract_json
        path tumour_alignment_xam
        path tumour_alignment_xam_index
        path normal_or_control_alignment_xam
        path normal_or_control_alignment_xam_index
        path candidate_bed
        path candidate_variants
        path reference
        path reference_index
        path clairs_model

    output:
        path "somatic_full_alignment_prediction_fragments", emit: somatic_full_alignment_prediction_fragments
        path "somatic_full_alignment_prediction_manifest.json", emit: somatic_full_alignment_prediction_manifest
        path "somatic_full_alignment_prediction_command.json", emit: somatic_full_alignment_prediction_command_json
        path "somatic_paired_snv_full_alignment.log", emit: somatic_paired_snv_full_alignment_logs
        path "somatic_provenance.json", emit: somatic_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-somatic-paired-snv-full-alignment-contract.json <<'JSON'
${contract_json}
JSON

    export TUMOUR_XAM="${tumour_alignment_xam}"
    export NORMAL_OR_CONTROL_XAM="${normal_or_control_alignment_xam}"
    export CANDIDATE_BED="${candidate_bed}"
    export CANDIDATE_VARIANTS="${candidate_variants}"
    export REFERENCE_FASTA="${reference}"
    export CLAIRS_MODEL="${clairs_model}"
    python3 - <<'PY'
import json
import os
import shlex
import subprocess
from pathlib import Path

contract = json.loads(Path("bounded-somatic-paired-snv-full-alignment-contract.json").read_text())
options = contract["clairs_options"]
clairs_path = os.environ.get("CLAIRS_PATH", "").strip()
if not clairs_path:
    raise EnvironmentError("CLAIRS_PATH must be set by the ClairS runtime container")
model_path = Path(os.environ["CLAIRS_MODEL"])
model_name = contract.get("clairs_model_name") or model_path.name
region_id = str(contract["region_id"])
variant_type = str(contract["variant_type"])
contig = str(contract["contig"])
tensor_dir = Path("full_alignment_tensor_can")
fragment_dir = Path("somatic_full_alignment_prediction_fragments")
tensor_dir.mkdir(exist_ok=True)
fragment_dir.mkdir(exist_ok=True)
tensor_path = tensor_dir / f"{region_id}.{variant_type}.tensor"
vcf_prefix = "indel_fa" if variant_type == "indel" else "fa"
vcf_path = fragment_dir / f"{vcf_prefix}_{region_id}.vcf"
checkpoint = model_path / ("indel/full_alignment.pkl" if variant_type == "indel" else "full_alignment.pkl")

create_tensor = [
    "pypy3",
    str(Path(clairs_path) / "clairs.py"),
    "create_pair_tensor",
    "--normal_bam_fn", os.environ["NORMAL_OR_CONTROL_XAM"],
    "--tumor_bam_fn", os.environ["TUMOUR_XAM"],
    "--ref_fn", os.environ["REFERENCE_FASTA"],
    "--samtools", "samtools",
    "--ctg_name", contig,
    "--candidates_bed_regions", os.environ["CANDIDATE_BED"],
    "--tensor_can_fn", str(tensor_path),
    "--platform", options["platform"],
]

predict = [
    "python3",
    str(Path(clairs_path) / "clairs.py"),
    "predict",
    "--tensor_fn", str(tensor_path),
    "--call_fn", str(vcf_path),
    "--chkpnt_fn", str(checkpoint),
    "--platform", options["platform"],
    "--use_gpu", "False",
    "--ctg_name", contig,
    "--enable_indel_calling", "True" if variant_type == "indel" else "False",
]
if options["show_ref"]:
    predict.append("--show_ref")
if options["show_germline"]:
    predict.append("--show_germline")

command_metadata = {
    "schema": "wf-human-variation.somatic_paired_snv_full_alignment_command.v1",
    "task_key": contract["task_key"],
    "tool": "clairs",
    "stage": "paired_full_alignment_tensor_prediction",
    "create_pair_tensor": create_tensor,
    "predict": predict,
    "structured_options": options,
    "region": {
        "region_id": region_id,
        "contig": contig,
        "variant_type": variant_type,
        "alignment_state": contract["alignment_state"],
    },
    "candidate_inputs": {
        "candidate_bed": contract["candidate_bed"],
        "candidate_variants": contract["candidate_variants"],
    },
    "model": {
        "path": contract["clairs_model"],
        "name": model_name,
        "checkpoint": str(checkpoint),
    },
}
Path("somatic_full_alignment_prediction_command.json").write_text(json.dumps(command_metadata, indent=2, sort_keys=True) + "\\n")
Path("run-clairs-full-alignment.command.sh").write_text(
    " ".join(shlex.quote(part) for part in create_tensor) + "\\n" +
    " ".join(shlex.quote(part) for part in predict) + "\\n"
)

with Path("somatic_paired_snv_full_alignment.log").open("w") as log:
    subprocess.run(["bash", "run-clairs-full-alignment.command.sh"], check=True, stdout=log, stderr=subprocess.STDOUT)
PY

    python3 - <<'PY'
import datetime
import json
import shutil
from pathlib import Path


def copy_output(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.is_dir():
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(source, target)
    else:
        shutil.copy2(source, target)


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


contract = json.loads(Path("bounded-somatic-paired-snv-full-alignment-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
command_metadata = json.loads(Path("somatic_full_alignment_prediction_command.json").read_text())
fragment_files = sorted(str(path) for path in Path("somatic_full_alignment_prediction_fragments").glob("*.vcf"))
manifest = {
    "schema": "wf-human-variation.somatic_full_alignment_prediction_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "paired_role": contract["paired_role"],
    "tumour_sample_id": contract["tumour_sample_id"],
    "normal_or_control_sample_id": contract["normal_or_control_sample_id"],
    "reference_id": contract["reference_id"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
    "region": command_metadata["region"],
    "clairs_model": contract["clairs_model"],
    "clairs_model_name": contract["clairs_model_name"] or Path(contract["clairs_model"]).name,
    "clairs_model_digest": contract["clairs_model_digest"],
    "clairs_model_table_digest": contract["clairs_model_table_digest"],
    "clairs_config_digest": contract["clairs_config_digest"],
    "clairs_options_digest": contract["clairs_options_digest"],
    "container_digest": contract["container_digest"],
    "fragment_files": fragment_files,
    "outputs": {key: str(value) for key, value in output_paths.items()},
}
Path("somatic_full_alignment_prediction_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.somatic_provenance.v1",
    "task_family": contract["task_family"],
    "task_stage": "paired_full_alignment_tensor_prediction",
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "tool": "clairs",
    "container_digest": contract["container_digest"],
    "command_arguments": command_metadata,
    "input_checksums": {
        "tumour_alignment_xam": contract["tumour_alignment_xam_digest"],
        "tumour_alignment_xam_index": contract["tumour_alignment_xam_index_digest"],
        "normal_or_control_alignment_xam": contract["normal_or_control_alignment_xam_digest"],
        "normal_or_control_alignment_xam_index": contract["normal_or_control_alignment_xam_index_digest"],
        "candidate_bed": contract["candidate_bed_digest"],
        "candidate_variants": contract["candidate_variants_digest"],
        "reference": contract["reference_digest"],
        "clairs_model": contract["clairs_model_digest"],
        "clairs_model_table": contract["clairs_model_table_digest"],
        "clairs_config": contract["clairs_config_digest"],
        "clairs_options": contract["clairs_options_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
}
Path("somatic_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.somatic_full_alignment_prediction_qc.v1",
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "region": command_metadata["region"],
    "fragment_count": len(fragment_files),
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

for kind, source in {
    "somatic_full_alignment_prediction_fragments": Path("somatic_full_alignment_prediction_fragments"),
    "somatic_full_alignment_prediction_manifest": Path("somatic_full_alignment_prediction_manifest.json"),
    "somatic_full_alignment_prediction_command_json": Path("somatic_full_alignment_prediction_command.json"),
    "somatic_paired_snv_full_alignment_logs": Path("somatic_paired_snv_full_alignment.log"),
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
    "outputs": [{"kind": kind, "path": str(output_paths[kind]), "required": True} for kind in sorted(output_paths)],
    "metadata": {
        "bounded_entry": contract["entry_name"],
        "entry_schema": contract["entry_schema"],
        "analysis_intent_id": contract["analysis_intent_id"],
        "pair_id": contract["pair_id"],
        "region_id": contract["region_id"],
        "variant_type": contract["variant_type"],
        "alignment_state": contract["alignment_state"],
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}


process runBoundedSomaticPairedSnvMergeTask {
    label "somatic_clairs"
    tag "${entry.analysis_intent_id}:${entry.pair_id}:${entry.variant_type}:${entry.task_key}"

    cpus { entry.clairs_options.threads }
    memory { 4.GB * task.attempt }
    maxRetries 1
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }

    input:
        val entry
        val contract_json
        path pileup_prediction_fragments
        path full_alignment_prediction_fragments
        path contigs_file
        path reference
        path reference_index

    output:
        path "somatic_snv.vcf.gz", emit: somatic_snv_vcf
        path "somatic_snv.vcf.gz.tbi", emit: somatic_snv_vcf_index
        path "somatic_paired_snv_manifest.json", emit: somatic_paired_snv_manifest
        path "somatic_paired_snv_command.json", emit: somatic_paired_snv_command_json
        path "somatic_paired_snv.log", emit: somatic_paired_snv_logs
        path "somatic_provenance.json", emit: somatic_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-somatic-paired-snv-merge-contract.json <<'JSON'
${contract_json}
JSON

    export PILEUP_FRAGMENTS="${pileup_prediction_fragments}"
    export FULL_ALIGNMENT_FRAGMENTS="${full_alignment_prediction_fragments}"
    export CONTIGS_FILE="${contigs_file}"
    export REFERENCE_FASTA="${reference}"
    python3 - <<'PY'
import json
import os
import shlex
import subprocess
from pathlib import Path

contract = json.loads(Path("bounded-somatic-paired-snv-merge-contract.json").read_text())
options = contract["clairs_options"]
clairs_path = os.environ.get("CLAIRS_PATH", "").strip()
if not clairs_path:
    raise EnvironmentError("CLAIRS_PATH must be set by the ClairS runtime container")
variant_type = str(contract["variant_type"])
sample_name = str(contract["tumour_sample_id"])
pileup_prefix = "indel_p_" if variant_type == "indel" else "p_"
full_prefix = "indel_fa_" if variant_type == "indel" else "fa_"
pileup_vcf = Path(f"pileup_{variant_type}.vcf")
full_alignment_vcf = Path(f"full_alignment_{variant_type}.vcf")
merged_vcf = Path(f"{sample_name}_somatic_{variant_type}.vcf")
merged_gz = Path(f"{sample_name}_somatic_{variant_type}.vcf.gz")
merged_tbi = Path(f"{sample_name}_somatic_{variant_type}.vcf.gz.tbi")

sort_pileup = [
    "pypy3",
    str(Path(clairs_path) / "clairs.py"),
    "sort_vcf",
    "--ref_fn", os.environ["REFERENCE_FASTA"],
    "--contigs_fn", os.environ["CONTIGS_FILE"],
    "--input_dir", os.environ["PILEUP_FRAGMENTS"],
    "--vcf_fn_prefix", pileup_prefix,
    "--output_fn", str(pileup_vcf),
]
sort_full_alignment = [
    "pypy3",
    str(Path(clairs_path) / "clairs.py"),
    "sort_vcf",
    "--ref_fn", os.environ["REFERENCE_FASTA"],
    "--contigs_fn", os.environ["CONTIGS_FILE"],
    "--input_dir", os.environ["FULL_ALIGNMENT_FRAGMENTS"],
    "--vcf_fn_prefix", full_prefix,
    "--output_fn", str(full_alignment_vcf),
]
merge_vcf = [
    "pypy3",
    str(Path(clairs_path) / "clairs.py"),
    "merge_vcf",
    "--ref_fn", os.environ["REFERENCE_FASTA"],
    "--pileup_vcf_fn", str(pileup_vcf),
    "--full_alignment_vcf_fn", str(full_alignment_vcf),
    "--output_fn", str(merged_vcf),
    "--platform", options["platform"],
    "--qual", str(options["qual"]),
    "--sample_name", sample_name,
]
if variant_type == "indel":
    merge_vcf.extend(["--enable_indel_calling", "True", "--indel_calling"])
bgzip_vcf = ["bgzip", "-f", str(merged_vcf)]
tabix_vcf = ["tabix", "-f", "-p", "vcf", str(merged_gz)]
count_variants = ["bcftools", "index", "-n", str(merged_gz)]

command_metadata = {
    "schema": "wf-human-variation.somatic_paired_snv_command.v1",
    "task_key": contract["task_key"],
    "tool": "clairs",
    "stage": "paired_final_vcf_merge",
    "sort_pileup": sort_pileup,
    "sort_full_alignment": sort_full_alignment,
    "merge_vcf": merge_vcf,
    "bgzip_vcf": bgzip_vcf,
    "tabix_vcf": tabix_vcf,
    "count_variants": count_variants,
    "structured_options": options,
    "variant_type": variant_type,
    "input_fragments": {
        "pileup_prediction_fragments": contract["pileup_prediction_fragments"],
        "full_alignment_prediction_fragments": contract["full_alignment_prediction_fragments"],
    },
}
Path("somatic_paired_snv_command.json").write_text(json.dumps(command_metadata, indent=2, sort_keys=True) + "\\n")
Path("run-clairs-merge.command.sh").write_text(
    " ".join(shlex.quote(part) for part in sort_pileup) + "\\n" +
    " ".join(shlex.quote(part) for part in sort_full_alignment) + "\\n" +
    " ".join(shlex.quote(part) for part in merge_vcf) + "\\n"
)

with Path("somatic_paired_snv.log").open("w") as log:
    subprocess.run(["bash", "run-clairs-merge.command.sh"], check=True, stdout=log, stderr=subprocess.STDOUT)
    if not merged_gz.exists():
        if merged_vcf.exists():
            subprocess.run(bgzip_vcf, check=True, stdout=log, stderr=subprocess.STDOUT)
        else:
            raise FileNotFoundError(f"ClairS merge did not produce {merged_gz} or {merged_vcf}")
    if not merged_tbi.exists():
        subprocess.run(tabix_vcf, check=True, stdout=log, stderr=subprocess.STDOUT)
    variant_count = 0
    try:
        completed = subprocess.run(
            count_variants,
            check=True,
            capture_output=True,
            text=True,
        )
        variant_count = int(completed.stdout.strip() or "0")
    except Exception as error:
        log.write(f"[WARN] unable to count variants in {merged_gz}: {error}\\n")

Path("somatic_snv.vcf.gz").write_bytes(merged_gz.read_bytes())
Path("somatic_snv.vcf.gz.tbi").write_bytes(merged_tbi.read_bytes())
Path("variant-count.txt").write_text(str(variant_count) + "\\n")
PY

    python3 - <<'PY'
import datetime
import json
import shutil
from pathlib import Path


def copy_output(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.is_dir():
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(source, target)
    else:
        shutil.copy2(source, target)


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


contract = json.loads(Path("bounded-somatic-paired-snv-merge-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
command_metadata = json.loads(Path("somatic_paired_snv_command.json").read_text())
variant_count = int(Path("variant-count.txt").read_text().strip() or "0")
manifest = {
    "schema": "wf-human-variation.somatic_paired_snv_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "paired_role": contract["paired_role"],
    "tumour_sample_id": contract["tumour_sample_id"],
    "normal_or_control_sample_id": contract["normal_or_control_sample_id"],
    "reference_id": contract["reference_id"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
    "variant_type": contract["variant_type"],
    "clairs_config_digest": contract["clairs_config_digest"],
    "clairs_options_digest": contract["clairs_options_digest"],
    "container_digest": contract["container_digest"],
    "variant_count": variant_count,
    "outputs": {key: str(value) for key, value in output_paths.items()},
}
Path("somatic_paired_snv_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.somatic_provenance.v1",
    "task_family": contract["task_family"],
    "task_stage": "paired_final_vcf_merge",
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "tool": "clairs",
    "container_digest": contract["container_digest"],
    "command_arguments": command_metadata,
    "input_checksums": {
        "pileup_prediction_fragments": contract["pileup_prediction_fragments_digest"],
        "full_alignment_prediction_fragments": contract["full_alignment_prediction_fragments_digest"],
        "contigs_file": contract["contigs_file_digest"],
        "reference": contract["reference_digest"],
        "clairs_config": contract["clairs_config_digest"],
        "clairs_options": contract["clairs_options_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
}
Path("somatic_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.somatic_paired_snv_qc.v1",
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "variant_type": contract["variant_type"],
    "variant_count": variant_count,
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

for kind, source in {
    "somatic_snv_vcf": Path("somatic_snv.vcf.gz"),
    "somatic_snv_vcf_index": Path("somatic_snv.vcf.gz.tbi"),
    "somatic_paired_snv_manifest": Path("somatic_paired_snv_manifest.json"),
    "somatic_paired_snv_command_json": Path("somatic_paired_snv_command.json"),
    "somatic_paired_snv_logs": Path("somatic_paired_snv.log"),
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
    "outputs": [{"kind": kind, "path": str(output_paths[kind]), "required": True} for kind in sorted(output_paths)],
    "metadata": {
        "bounded_entry": contract["entry_name"],
        "entry_schema": contract["entry_schema"],
        "analysis_intent_id": contract["analysis_intent_id"],
        "pair_id": contract["pair_id"],
        "variant_type": contract["variant_type"],
        "variant_count": variant_count,
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}


process runBoundedSomaticPairedSnvHaplotypeFilterTask {
    label "somatic_clairs"
    tag "${entry.analysis_intent_id}:${entry.pair_id}:${entry.contig}:${entry.variant_type}:${entry.task_key}"

    cpus { entry.haplotype_filter_options.threads }
    memory { (2.GB * task.cpus) + 3.GB }
    maxRetries 1
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }

    input:
        val entry
        val contract_json
        path somatic_snv_vcf
        path somatic_snv_vcf_index
        path somatic_pileup_vcf
        path somatic_full_alignment_vcf
        path tumour_haplotagged_xam
        path tumour_haplotagged_xam_index
        path germline_vcf
        path germline_vcf_index
        path reference
        path reference_index

    output:
        path "somatic_haplotype_filtered.vcf.gz", emit: somatic_haplotype_filtered_vcf
        path "somatic_haplotype_filtered.vcf.gz.tbi", emit: somatic_haplotype_filtered_vcf_index
        path "somatic_haplotype_filter_manifest.json", emit: somatic_haplotype_filter_manifest
        path "somatic_haplotype_filter_command.json", emit: somatic_haplotype_filter_command_json
        path "somatic_haplotype_filter_state.json", emit: somatic_haplotype_filter_state
        path "somatic_haplotype_filter.log", emit: somatic_haplotype_filter_logs
        path "somatic_provenance.json", emit: somatic_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-somatic-paired-snv-haplotype-filter-contract.json <<'JSON'
${contract_json}
JSON

    export SOMATIC_SNV_VCF="${somatic_snv_vcf}"
    export SOMATIC_SNV_VCF_INDEX="${somatic_snv_vcf_index}"
    export SOMATIC_PILEUP_VCF="${somatic_pileup_vcf}"
    export SOMATIC_FULL_ALIGNMENT_VCF="${somatic_full_alignment_vcf}"
    export TUMOUR_HAPLOTAGGED_XAM="${tumour_haplotagged_xam}"
    export TUMOUR_HAPLOTAGGED_XAM_INDEX="${tumour_haplotagged_xam_index}"
    export GERMLINE_VCF="${germline_vcf}"
    export GERMLINE_VCF_INDEX="${germline_vcf_index}"
    export REFERENCE_FASTA="${reference}"
    python3 - <<'PY'
import datetime
import json
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path


def copy_output(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def optional_stage(contract_key, env_name):
    declared = contract.get(contract_key) or ""
    staged = os.environ.get(env_name, "")
    if not declared:
        return ""
    if not staged or not Path(staged).exists():
        raise FileNotFoundError(f"{contract_key} was declared but was not staged: {declared}")
    return staged


def run_command(command, log):
    log.write(" ".join(shlex.quote(part) for part in command) + "\\n")
    log.flush()
    return subprocess.run(command, check=False, stdout=log, stderr=subprocess.STDOUT)


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


contract = json.loads(Path("bounded-somatic-paired-snv-haplotype-filter-contract.json").read_text())
options = contract["haplotype_filter_options"]
clairs_options = contract["clairs_options"]
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
state = "completed"
failure = None
commands = []
variant_type = str(contract["variant_type"])
contig = str(contract["contig"])
sample_name = str(contract["tumour_sample_id"])
filtered_pileup = Path("vcf_output") / ("indel_pileup_filter.vcf" if variant_type == "indel" else "pileup_filter.vcf")
filtered_full = Path("vcf_output") / ("indel_full_alignment_filter.vcf" if variant_type == "indel" else "full_alignment_filter.vcf")
merged_vcf = Path("somatic_haplotype_filtered.vcf")
merged_gz = Path("somatic_haplotype_filtered.vcf.gz")
merged_tbi = Path("somatic_haplotype_filtered.vcf.gz.tbi")
Path("vcf_output").mkdir(exist_ok=True)

with Path("somatic_haplotype_filter.log").open("w") as log:
    if not options["enabled"]:
        state = "skipped_disabled"
        shutil.copy2(os.environ["SOMATIC_SNV_VCF"], merged_gz)
        shutil.copy2(os.environ["SOMATIC_SNV_VCF_INDEX"], merged_tbi)
    else:
        clairs_path = os.environ.get("CLAIRS_PATH", "").strip()
        if not clairs_path:
            state = "failed"
            failure = {"stage": "environment", "reason": "CLAIRS_PATH must be set by the ClairS runtime container"}
        else:
            germline_vcf = optional_stage("germline_vcf", "GERMLINE_VCF")
            haplotype_filter = [
                "pypy3",
                str(Path(clairs_path) / "clairs.py"),
                "haplotype_filtering",
                "--tumor_bam_fn", os.environ["TUMOUR_HAPLOTAGGED_XAM"],
                "--ref_fn", os.environ["REFERENCE_FASTA"],
                "--pileup_vcf_fn", os.environ["SOMATIC_PILEUP_VCF"],
                "--full_alignment_vcf_fn", os.environ["SOMATIC_FULL_ALIGNMENT_VCF"],
                "--output_dir", "vcf_output/",
                "--samtools", "samtools",
                "--threads", str(options["threads"]),
                "--ctg_name", contig,
            ]
            if germline_vcf:
                haplotype_filter.extend(["--germline_vcf_fn", germline_vcf])
            if options["show_ref"] or clairs_options["show_ref"]:
                haplotype_filter.append("--show_ref")
            if options["is_indel"] or variant_type == "indel":
                haplotype_filter.append("--is_indel")
            if options["debug"]:
                haplotype_filter.append("--debug")
            merge_vcf = [
                "pypy3",
                str(Path(clairs_path) / "clairs.py"),
                "merge_vcf",
                "--ref_fn", os.environ["REFERENCE_FASTA"],
                "--pileup_vcf_fn", str(filtered_pileup),
                "--full_alignment_vcf_fn", str(filtered_full),
                "--output_fn", str(merged_vcf),
                "--platform", clairs_options["platform"],
                "--qual", str(clairs_options["qual"]),
                "--sample_name", sample_name,
            ]
            if variant_type == "indel":
                merge_vcf.extend(["--enable_indel_calling", "True", "--indel_calling"])
            bgzip_vcf = ["bgzip", "-f", str(merged_vcf)]
            tabix_vcf = ["tabix", "-f", "-p", "vcf", str(merged_gz)]
            commands = [haplotype_filter, merge_vcf, bgzip_vcf, tabix_vcf]
            for command in commands[:2]:
                result = run_command(command, log)
                if result.returncode != 0:
                    state = "failed"
                    failure = {"stage": command[2] if len(command) > 2 else command[0], "exit_code": result.returncode}
                    break
            if state != "failed":
                if not merged_gz.exists():
                    result = run_command(bgzip_vcf, log)
                    if result.returncode != 0:
                        state = "failed"
                        failure = {"stage": "bgzip", "exit_code": result.returncode}
                if state != "failed" and not merged_tbi.exists():
                    result = run_command(tabix_vcf, log)
                    if result.returncode != 0:
                        state = "failed"
                        failure = {"stage": "tabix", "exit_code": result.returncode}

command_metadata = {
    "schema": "wf-human-variation.somatic_haplotype_filter_command.v1",
    "task_key": contract["task_key"],
    "tool": "clairs",
    "stage": "paired_haplotype_filtering",
    "state": state,
    "commands": commands,
    "structured_options": options,
    "clairs_options": clairs_options,
    "inputs": {
        "somatic_snv_vcf": contract["somatic_snv_vcf"],
        "somatic_pileup_vcf": contract["somatic_pileup_vcf"],
        "somatic_full_alignment_vcf": contract["somatic_full_alignment_vcf"],
        "tumour_haplotagged_xam": contract["tumour_haplotagged_xam"],
        "germline_vcf": contract["germline_vcf"] or None,
    },
}
Path("somatic_haplotype_filter_command.json").write_text(json.dumps(command_metadata, indent=2, sort_keys=True) + "\\n")

state_payload = {
    "schema": "wf-human-variation.somatic_haplotype_filter_state.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "state": state,
    "failure": failure,
    "policy": {"enabled": options["enabled"], "variant_type": variant_type, "contig": contig},
}
Path("somatic_haplotype_filter_state.json").write_text(json.dumps(state_payload, indent=2, sort_keys=True) + "\\n")

manifest = {
    "schema": "wf-human-variation.somatic_haplotype_filter_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "paired_role": contract["paired_role"],
    "tumour_sample_id": contract["tumour_sample_id"],
    "normal_or_control_sample_id": contract["normal_or_control_sample_id"],
    "reference_id": contract["reference_id"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
    "variant_type": variant_type,
    "contig": contig,
    "state": state,
    "clairs_config_digest": contract["clairs_config_digest"],
    "clairs_options_digest": contract["clairs_options_digest"],
    "haplotype_filter_config_digest": contract["haplotype_filter_config_digest"],
    "haplotype_filter_options_digest": contract["haplotype_filter_options_digest"],
    "container_digest": contract["container_digest"],
    "outputs": {key: str(value) for key, value in output_paths.items()},
}
Path("somatic_haplotype_filter_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.somatic_provenance.v1",
    "task_family": contract["task_family"],
    "task_stage": "paired_haplotype_filtering",
    "task_key": contract["task_key"],
    "tool": "clairs",
    "container_digest": contract["container_digest"],
    "command_arguments": command_metadata,
    "input_checksums": {
        "somatic_snv_vcf": contract["somatic_snv_vcf_digest"],
        "somatic_snv_vcf_index": contract["somatic_snv_vcf_index_digest"],
        "somatic_pileup_vcf": contract["somatic_pileup_vcf_digest"],
        "somatic_full_alignment_vcf": contract["somatic_full_alignment_vcf_digest"],
        "tumour_haplotagged_xam": contract["tumour_haplotagged_xam_digest"],
        "tumour_haplotagged_xam_index": contract["tumour_haplotagged_xam_index_digest"],
        "reference": contract["reference_digest"],
        "germline_vcf": contract["germline_vcf_digest"] or None,
        "haplotype_filter_config": contract["haplotype_filter_config_digest"],
        "haplotype_filter_options": contract["haplotype_filter_options_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
}
Path("somatic_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.somatic_haplotype_filter_qc.v1",
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "variant_type": variant_type,
    "contig": contig,
    "state": state,
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

if state != "failed":
    copy_output(merged_gz, output_paths["somatic_haplotype_filtered_vcf"])
    copy_output(merged_tbi, output_paths["somatic_haplotype_filtered_vcf_index"])
for kind, source in {
    "somatic_haplotype_filter_manifest": Path("somatic_haplotype_filter_manifest.json"),
    "somatic_haplotype_filter_command_json": Path("somatic_haplotype_filter_command.json"),
    "somatic_haplotype_filter_state": Path("somatic_haplotype_filter_state.json"),
    "somatic_haplotype_filter_logs": Path("somatic_haplotype_filter.log"),
    "somatic_provenance": Path("somatic_provenance.json"),
    "qc_stats": Path("qc_stats.json"),
}.items():
    copy_output(source, output_paths[kind])

if state == "failed":
    sys.exit(1)

marker_path = Path(contract["completion_marker_path"])
marker_path.parent.mkdir(parents=True, exist_ok=True)
marker = {
    "marker_schema": "gnostikon.task_completion.v1",
    "task_key": contract["task_key"],
    "task_family": contract["task_family"],
    "status": "succeeded",
    "completed_at_utc": utc_now(),
    "outputs": [{"kind": kind, "path": str(output_paths[kind]), "required": True} for kind in sorted(output_paths)],
    "metadata": {
        "bounded_entry": contract["entry_name"],
        "entry_schema": contract["entry_schema"],
        "analysis_intent_id": contract["analysis_intent_id"],
        "pair_id": contract["pair_id"],
        "variant_type": variant_type,
        "contig": contig,
        "state": state,
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
