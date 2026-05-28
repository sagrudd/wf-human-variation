process runBoundedSomaticDifferentialMethylationTask {
    label "dss"
    tag "${entry.analysis_intent_id}:${entry.pair_id}:${entry.modification_code}:${entry.task_key}"

    cpus { entry.dss_options.threads > 4 ? 4 : entry.dss_options.threads }
    memory { task.cpus * 19.GB }
    maxRetries 1
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }

    input:
        val entry
        val contract_json
        path tumour_dss_input_tsv
        path normal_or_control_dss_input_tsv

    output:
        path "${entry.pair_id}.${entry.modification_code}.dml.tsv", emit: somatic_dml_tsv
        path "${entry.pair_id}.${entry.modification_code}.dmr.tsv", emit: somatic_dmr_tsv
        path "somatic_differential_methylation_manifest.json", emit: somatic_differential_methylation_manifest
        path "somatic_differential_methylation_command.json", emit: somatic_differential_methylation_command_json
        path "dss.log", emit: somatic_differential_methylation_log
        path "r_versions.tsv", emit: somatic_r_versions
        path "somatic_provenance.json", emit: somatic_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-somatic-differential-methylation-contract.json <<'JSON'
${contract_json}
JSON

    export TUMOUR_DSS_INPUT_TSV="${tumour_dss_input_tsv}"
    export NORMAL_OR_CONTROL_DSS_INPUT_TSV="${normal_or_control_dss_input_tsv}"
    python3 - <<'PY'
import json
import os
import shlex
from pathlib import Path


def r_bool(value):
    return "TRUE" if value else "FALSE"


contract = json.loads(Path("bounded-somatic-differential-methylation-contract.json").read_text())
options = contract["dss_options"]
if contract["reference_genome_build"] not in {"hg19", "hg38"}:
    raise ValueError("somatic differential methylation requires validated hg19 or hg38 reference_genome_build")

Path("tumor.bed").symlink_to(Path(os.environ["TUMOUR_DSS_INPUT_TSV"]).resolve())
Path("normal.bed").symlink_to(Path(os.environ["NORMAL_OR_CONTROL_DSS_INPUT_TSV"]).resolve())
final_dml = f"{contract['pair_id']}.{contract['modification_code']}.dml.tsv"
final_dmr = f"{contract['pair_id']}.{contract['modification_code']}.dmr.tsv"

r_script = f'''
suppressPackageStartupMessages({{
    library(DSS)
    require(bsseq)
    require(data.table)
}})
options(scipen=999)

tumor <- fread("tumor.bed", sep="\\t", header=TRUE)
normal <- fread("normal.bed", sep="\\t", header=TRUE)
BSobj <- makeBSseqData(list(tumor, normal), c("Tumor", "Normal"))
dmlTest <- DMLtest(
    BSobj,
    group1=c("Tumor"),
    group2=c("Normal"),
    equal.disp={r_bool(options["equal_disp"])},
    smoothing={r_bool(options["smoothing"])},
    smoothing.span={options["smoothing_span"]},
    ncores={options["threads"]}
)
dmls <- callDML(
    dmlTest,
    delta={options["delta"]},
    p.threshold={options["p_threshold"]}
)
dmrs <- callDMR(
    dmlTest,
    delta={options["delta"]},
    p.threshold={options["p_threshold"]},
    minlen={options["minlen"]},
    minCG={options["min_cg"]},
    dis.merge={options["dis_merge"]},
    pct.sig={options["pct_sig"]}
)
write.table(dmls, "{final_dml}", sep="\\t", quote=FALSE, col.names=TRUE, row.names=FALSE)
write.table(dmrs, "{final_dmr}", sep="\\t", quote=FALSE, col.names=TRUE, row.names=FALSE)
'''
Path("run-dss.R").write_text(r_script)

version_script = '''
suppressPackageStartupMessages({
    packages <- c("DSS", "bsseq", "data.table")
})
cat("package\\tversion\\n")
for (package in packages) {
    cat(package, as.character(packageVersion(package)), sep="\\t")
    cat("\\n")
}
'''
Path("record-r-versions.R").write_text(version_script)

commands = [
    "Rscript record-r-versions.R > r_versions.tsv",
    "Rscript run-dss.R > dss.log 2>&1",
]
Path("run-somatic-differential-methylation.sh").write_text("\\n".join(commands) + "\\n")
command_metadata = {
    "schema": "wf-human-variation.somatic_differential_methylation_command.v1",
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "modification_code": contract["modification_code"],
    "tools": ["DSS", "bsseq", "data.table", "Rscript"],
    "commands": commands,
    "dss_options": options,
    "inputs": {
        "tumour_dss_input_tsv": "tumor.bed",
        "normal_or_control_dss_input_tsv": "normal.bed",
    },
}
Path("somatic_differential_methylation_command.json").write_text(json.dumps(command_metadata, indent=2, sort_keys=True) + "\\n")
PY

    bash run-somatic-differential-methylation.sh

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


contract = json.loads(Path("bounded-somatic-differential-methylation-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
command_metadata = json.loads(Path("somatic_differential_methylation_command.json").read_text())
final_dml = Path(f"{contract['pair_id']}.{contract['modification_code']}.dml.tsv")
final_dmr = Path(f"{contract['pair_id']}.{contract['modification_code']}.dmr.tsv")
for output in (final_dml, final_dmr, Path("dss.log"), Path("r_versions.tsv")):
    if not output.exists():
        raise FileNotFoundError(f"expected DSS output was not produced: {output}")

manifest = {
    "schema": "wf-human-variation.somatic_differential_methylation_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "tumour_sample_id": contract["tumour_sample_id"],
    "normal_or_control_sample_id": contract["normal_or_control_sample_id"],
    "paired_role": contract["paired_role"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
    "reference_id": contract["reference_id"],
    "reference_genome_build": contract["reference_genome_build"],
    "modification_code": contract["modification_code"],
    "tumour_dss_input_tsv_digest": contract["tumour_dss_input_tsv_digest"],
    "normal_or_control_dss_input_tsv_digest": contract["normal_or_control_dss_input_tsv_digest"],
    "dss_config_digest": contract["dss_config_digest"],
    "dss_options_digest": contract["dss_options_digest"],
    "r_bioconductor_lock_digest": contract["r_bioconductor_lock_digest"],
    "container_digest": contract["container_digest"],
    "outputs": {
        "somatic_dml_tsv": str(output_paths["somatic_dml_tsv"]),
        "somatic_dmr_tsv": str(output_paths["somatic_dmr_tsv"]),
        "somatic_differential_methylation_manifest": str(output_paths["somatic_differential_methylation_manifest"]),
        "somatic_differential_methylation_command_json": str(output_paths["somatic_differential_methylation_command_json"]),
        "somatic_differential_methylation_log": str(output_paths["somatic_differential_methylation_log"]),
        "somatic_r_versions": str(output_paths["somatic_r_versions"]),
    },
    "removed_products": {
        "html_report": {"requested": False, "available": False, "reason": "removed_from_humvar3_contract"},
        "free_form_shell_arguments": {"requested": False, "available": False, "reason": "structured_options_required"},
    },
}
Path("somatic_differential_methylation_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.somatic_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "tool": "DSS",
    "container_digest": contract["container_digest"],
    "command_arguments": command_metadata,
    "input_checksums": {
        "tumour_dss_input_tsv": contract["tumour_dss_input_tsv_digest"],
        "normal_or_control_dss_input_tsv": contract["normal_or_control_dss_input_tsv_digest"],
        "dss_config": contract["dss_config_digest"],
        "dss_options": contract["dss_options_digest"],
        "r_bioconductor_lock": contract["r_bioconductor_lock_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
}
Path("somatic_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.somatic_differential_methylation_qc.v1",
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"],
    "modification_code": contract["modification_code"],
    "task_key": contract["task_key"],
    "somatic_dml_tsv": str(output_paths["somatic_dml_tsv"]),
    "somatic_dmr_tsv": str(output_paths["somatic_dmr_tsv"]),
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

for kind, source in {
    "somatic_dml_tsv": final_dml,
    "somatic_dmr_tsv": final_dmr,
    "somatic_differential_methylation_manifest": Path("somatic_differential_methylation_manifest.json"),
    "somatic_differential_methylation_command_json": Path("somatic_differential_methylation_command.json"),
    "somatic_differential_methylation_log": Path("dss.log"),
    "somatic_r_versions": Path("r_versions.tsv"),
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
        "modification_code": contract["modification_code"],
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
