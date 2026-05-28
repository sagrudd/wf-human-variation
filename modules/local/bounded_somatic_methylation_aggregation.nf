process runBoundedSomaticMethylationAggregationTask {
    label "wf_human_mod"
    tag "${entry.analysis_intent_id}:${entry.sample_role}:${entry.sample_id}:${entry.reference_id}:${entry.task_key}"

    cpus { entry.somatic_methylation_options.threads }
    memory { (2.GB * entry.somatic_methylation_options.threads) + 3.GB }

    input:
        val entry
        val contract_json
        path role_aggregate_xam
        path role_aggregate_xam_index
        path reference
        path reference_index

    output:
        path "somatic.bedmethyl.gz", emit: somatic_bedmethyl
        path "somatic.bedmethyl.gz.tbi", emit: somatic_bedmethyl_index
        path "somatic.5mC.bw", emit: somatic_bigwig
        path "somatic.mod_summary.tsv", emit: somatic_mod_summary
        path "somatic.dss.tsv", emit: somatic_dss_input_tsv
        path "somatic_methylation_aggregation_manifest.json", emit: somatic_methylation_aggregation_manifest
        path "somatic_methylation_aggregation_command.json", emit: somatic_methylation_aggregation_command_json
        path "modkit.log", emit: somatic_methylation_aggregation_log
        path "somatic_provenance.json", emit: somatic_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-somatic-methylation-aggregation-contract.json <<'JSON'
${contract_json}
JSON

    export ROLE_AGGREGATE_XAM="${role_aggregate_xam}"
    export ROLE_AGGREGATE_XAM_INDEX="${role_aggregate_xam_index}"
    export REFERENCE_FASTA="${reference}"
    export REFERENCE_INDEX="${reference_index}"
    python3 - <<'PY'
import json
import os
import shlex
from pathlib import Path


contract = json.loads(Path("bounded-somatic-methylation-aggregation-contract.json").read_text())
if contract["reference_genome_build"] not in {"hg19", "hg38"}:
    raise ValueError("somatic methylation aggregation requires validated hg19 or hg38 reference_genome_build")
options = contract["somatic_methylation_options"]

modkit_options = []
if options.get("combine_strands"):
    modkit_options.append("--combine-strands")
if options.get("cpg"):
    modkit_options.append("--cpg")
if options.get("preset"):
    modkit_options.extend(["--preset", str(options["preset"])])

mod_codes = []
for item in options["mod_codes"]:
    code, _, label = str(item).partition(":")
    if not code:
        raise ValueError("somatic methylation mod code entries must not be empty")
    mod_codes.append((code, label or code))
if not any(label == "5mC" for _, label in mod_codes):
    raise ValueError("somatic methylation options must include m:5mC")

input_xam = os.environ["ROLE_AGGREGATE_XAM"]
threads = str(options["threads"])
ref = os.environ["REFERENCE_FASTA"]
ref_idx = os.environ["REFERENCE_INDEX"]
dollar = chr(36)

commands = [
    f"workflow-glue check_valid_modbam {shlex.quote(input_xam)}",
    (
        "MODKIT_PROBS=$(modkit sample-probs "
        f"{shlex.quote(input_xam)} -p 0.1 --interval-size 5000000 --only-mapped "
        f"--threads {threads} 2> /dev/null | "
        "awk 'NR>1 {ORS=\" \"; print \"--filter-threshold \"$1\":\"$3}')"
    ),
    " ".join(
        [
            "modkit",
            "pileup",
            shlex.quote(input_xam),
            "somatic.bedmethyl.gz",
            "--modified-bases",
            "5mC",
            "5hmC",
            "--ref",
            shlex.quote(ref),
            "--log-filepath",
            "modkit.log",
            "${MODKIT_PROBS}",
            "--bgzf",
            "--threads",
            threads,
        ]
        + [shlex.quote(value) for value in modkit_options]
    ),
    "tabix -p bed somatic.bedmethyl.gz",
    f"modkit summary -t {threads} {shlex.quote(input_xam)} | awk 'BEGIN{{OFS=\"\\t\"}}; {{print {dollar}1,{dollar}2,{dollar}3,{dollar}4,{dollar}5,{dollar}6}}' > somatic.mod_summary.tsv",
    f"zcat somatic.bedmethyl.gz | awk -v OFS='\\t' 'BEGIN{{print \"chr\",\"pos\",\"N\",\"X\"}}{{print {dollar}1,{dollar}2,{dollar}10,{dollar}12}}' > somatic.dss.tsv",
]
for code, label in mod_codes:
    commands.append(
        f"zcat somatic.bedmethyl.gz | modkit bm tobigwig --sizes {shlex.quote(ref_idx)} "
        f"-t {threads} --mod-codes {shlex.quote(code)} - somatic.{shlex.quote(label)}.bw"
    )

Path("run-somatic-methylation-aggregation.sh").write_text("\\n".join(commands) + "\\n")
command_metadata = {
    "schema": "wf-human-variation.somatic_methylation_aggregation_command.v1",
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "sample_id": contract["sample_id"],
    "sample_role": contract["sample_role"],
    "tools": [
        "workflow-glue check_valid_modbam",
        "modkit sample-probs",
        "modkit pileup",
        "modkit summary",
        "modkit bm tobigwig",
        "tabix",
    ],
    "commands": commands,
    "somatic_methylation_options": options,
}
Path("somatic_methylation_aggregation_command.json").write_text(json.dumps(command_metadata, indent=2, sort_keys=True) + "\\n")
PY

    bash run-somatic-methylation-aggregation.sh

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


contract = json.loads(Path("bounded-somatic-methylation-aggregation-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
command_metadata = json.loads(Path("somatic_methylation_aggregation_command.json").read_text())

manifest = {
    "schema": "wf-human-variation.somatic_methylation_aggregation_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "sample_id": contract["sample_id"],
    "sample_role": contract["sample_role"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "reference_id": contract["reference_id"],
    "reference_genome_build": contract["reference_genome_build"],
    "role_aggregate_xam_digest": contract["role_aggregate_xam_digest"],
    "role_aggregate_xam_index_digest": contract["role_aggregate_xam_index_digest"],
    "modkit_config_digest": contract["modkit_config_digest"],
    "somatic_methylation_options_digest": contract["somatic_methylation_options_digest"],
    "container_digest": contract["container_digest"],
    "outputs": {
        "somatic_bedmethyl": str(output_paths["somatic_bedmethyl"]),
        "somatic_bedmethyl_index": str(output_paths["somatic_bedmethyl_index"]),
        "somatic_bigwig": str(output_paths["somatic_bigwig"]),
        "somatic_mod_summary": str(output_paths["somatic_mod_summary"]),
        "somatic_dss_input_tsv": str(output_paths["somatic_dss_input_tsv"]),
        "somatic_methylation_aggregation_manifest": str(output_paths["somatic_methylation_aggregation_manifest"]),
        "somatic_methylation_aggregation_command_json": str(output_paths["somatic_methylation_aggregation_command_json"]),
        "somatic_methylation_aggregation_log": str(output_paths["somatic_methylation_aggregation_log"]),
    },
    "removed_products": {
        "html_report": {"requested": False, "available": False, "reason": "removed_from_humvar3_contract"},
        "dss": {"requested": False, "available": False, "reason": "owned_by_somatic_differential_methylation"},
    },
}
Path("somatic_methylation_aggregation_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.somatic_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "sample_id": contract["sample_id"],
    "sample_role": contract["sample_role"],
    "tool": "modkit",
    "container_digest": contract["container_digest"],
    "command_arguments": command_metadata,
    "input_checksums": {
        "role_aggregate_xam": contract["role_aggregate_xam_digest"],
        "role_aggregate_xam_index": contract["role_aggregate_xam_index_digest"],
        "modkit_config": contract["modkit_config_digest"],
        "somatic_methylation_options": contract["somatic_methylation_options_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
}
Path("somatic_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.somatic_methylation_aggregation_qc.v1",
    "analysis_intent_id": contract["analysis_intent_id"],
    "sample_id": contract["sample_id"],
    "sample_role": contract["sample_role"],
    "task_key": contract["task_key"],
    "somatic_bedmethyl": str(output_paths["somatic_bedmethyl"]),
    "somatic_bigwig": str(output_paths["somatic_bigwig"]),
    "somatic_mod_summary": str(output_paths["somatic_mod_summary"]),
    "somatic_dss_input_tsv": str(output_paths["somatic_dss_input_tsv"]),
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

for kind, source in {
    "somatic_bedmethyl": Path("somatic.bedmethyl.gz"),
    "somatic_bedmethyl_index": Path("somatic.bedmethyl.gz.tbi"),
    "somatic_bigwig": Path("somatic.5mC.bw"),
    "somatic_mod_summary": Path("somatic.mod_summary.tsv"),
    "somatic_dss_input_tsv": Path("somatic.dss.tsv"),
    "somatic_methylation_aggregation_manifest": Path("somatic_methylation_aggregation_manifest.json"),
    "somatic_methylation_aggregation_command_json": Path("somatic_methylation_aggregation_command.json"),
    "somatic_methylation_aggregation_log": Path("modkit.log"),
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
        "sample_id": contract["sample_id"],
        "sample_role": contract["sample_role"],
        "reference_id": contract["reference_id"],
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
