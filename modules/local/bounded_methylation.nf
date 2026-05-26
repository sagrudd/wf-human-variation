process runBoundedMethylationTask {
    label "wf_human_mod"
    tag "${entry.sample_id}:${entry.reference_id}:${entry.methylation_mode}:${entry.task_key}"

    cpus { entry.methylation_options.threads }
    memory { (2.GB * entry.methylation_options.threads) + 3.GB }

    input:
        val entry
        val contract_json
        path aggregate_xam
        path aggregate_xam_index
        path haplotagged_xam
        path haplotagged_xam_index
        path reference
        path reference_index

    output:
        path "methylation.bedmethyl.gz", emit: bedmethyl
        path "methylation.5mC.bw", emit: bigwig
        path "methylation.hap1.bedmethyl.gz", optional: true, emit: bedmethyl_hap1
        path "methylation.hap2.bedmethyl.gz", optional: true, emit: bedmethyl_hap2
        path "methylation.hap1.5mC.bw", optional: true, emit: bigwig_hap1
        path "methylation.hap2.5mC.bw", optional: true, emit: bigwig_hap2
        path "methylation_manifest.json", emit: methylation_manifest
        path "methylation_provenance.json", emit: methylation_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-methylation-contract.json <<'JSON'
${contract_json}
JSON

    export AGGREGATE_XAM="${aggregate_xam}"
    export HAPLOTAGGED_XAM="${haplotagged_xam}"
    export REFERENCE_FASTA="${reference}"
    export REFERENCE_INDEX="${reference_index}"
    python3 - <<'PY'
import json
import os
import shlex
from pathlib import Path

contract = json.loads(Path("bounded-methylation-contract.json").read_text())
options = contract["methylation_options"]

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
        raise ValueError("methylation mod code entries must not be empty")
    mod_codes.append((code, label or code))

input_xam = os.environ["HAPLOTAGGED_XAM"] if contract["methylation_mode"] == "phased" else os.environ["AGGREGATE_XAM"]
sample = contract["sample_id"]
threads = str(options["threads"])
ref = os.environ["REFERENCE_FASTA"]
ref_idx = os.environ["REFERENCE_INDEX"]

commands = [
    f"workflow-glue check_valid_modbam {shlex.quote(input_xam)}",
    (
        "MODKIT_PROBS=$(modkit sample-probs "
        f"{shlex.quote(input_xam)} -p 0.1 --interval-size 5000000 --only-mapped "
        f"--threads {threads} 2> /dev/null | "
        "awk 'NR>1 {ORS=\" \"; print \"--filter-threshold \"$1\":\"$3}')"
    ),
]
base = [
    "modkit", "pileup",
    shlex.quote(input_xam),
]
if contract["methylation_mode"] == "phased":
    commands.append("mkdir -p phased-modkit")
    commands.append(" ".join(
        base
        + [
            "phased-modkit",
            "--modified-bases", "5mC", "5hmC",
            "--ref", shlex.quote(ref),
            "--phased",
            "--prefix", shlex.quote(f"{sample}.wf_mods"),
            "--log-filepath", "modkit.log",
            "${MODKIT_PROBS}",
            "--bgzf",
            "--threads", threads,
        ]
        + [shlex.quote(value) for value in modkit_options]
    ))
    commands.extend([
        "find phased-modkit -name '*combined.bed.gz' -o -name '*combined.bedmethyl.gz' > combined-bedmethyl-files.txt",
        "find phased-modkit -name '*1.bed.gz' -o -name '*1.bedmethyl.gz' > hap1-bedmethyl-files.txt",
        "find phased-modkit -name '*2.bed.gz' -o -name '*2.bedmethyl.gz' > hap2-bedmethyl-files.txt",
        "test -s combined-bedmethyl-files.txt",
        "zcat -f $(cat combined-bedmethyl-files.txt) | sort -k 1,1 -k2,2n | bgzip -c > methylation.bedmethyl.gz",
        "if [[ -s hap1-bedmethyl-files.txt ]]; then zcat -f $(cat hap1-bedmethyl-files.txt) | sort -k 1,1 -k2,2n | bgzip -c > methylation.hap1.bedmethyl.gz; fi",
        "if [[ -s hap2-bedmethyl-files.txt ]]; then zcat -f $(cat hap2-bedmethyl-files.txt) | sort -k 1,1 -k2,2n | bgzip -c > methylation.hap2.bedmethyl.gz; fi",
    ])
else:
    commands.append(" ".join(
        base
        + [
            "methylation.bedmethyl.gz",
            "--modified-bases", "5mC", "5hmC",
            "--ref", shlex.quote(ref),
            "--log-filepath", "modkit.log",
            "${MODKIT_PROBS}",
            "--bgzf",
            "--threads", threads,
        ]
        + [shlex.quote(value) for value in modkit_options]
    ))

for code, label in mod_codes:
    commands.append(
        f"zcat methylation.bedmethyl.gz | modkit bm tobigwig --sizes {shlex.quote(ref_idx)} "
        f"-t {threads} --mod-codes {shlex.quote(code)} - methylation.{shlex.quote(label)}.bw"
    )
    if contract["methylation_mode"] == "phased":
        commands.append(
            f"if [[ -s methylation.hap1.bedmethyl.gz ]]; then zcat methylation.hap1.bedmethyl.gz | modkit bm tobigwig --sizes {shlex.quote(ref_idx)} "
            f"-t {threads} --mod-codes {shlex.quote(code)} - methylation.hap1.{shlex.quote(label)}.bw; fi"
        )
        commands.append(
            f"if [[ -s methylation.hap2.bedmethyl.gz ]]; then zcat methylation.hap2.bedmethyl.gz | modkit bm tobigwig --sizes {shlex.quote(ref_idx)} "
            f"-t {threads} --mod-codes {shlex.quote(code)} - methylation.hap2.{shlex.quote(label)}.bw; fi"
        )

Path("run-methylation.sh").write_text("\\n".join(commands) + "\\n")
PY

    bash run-methylation.sh

    python3 - <<'PY'
import datetime
import json
import shutil
from pathlib import Path

contract = json.loads(Path("bounded-methylation-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}

manifest = {
    "schema": "wf-human-variation.methylation_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "methylation_mode": contract["methylation_mode"],
    "aggregate_xam_digest": contract["aggregate_xam_digest"],
    "haplotagged_xam_digest": contract["haplotagged_xam_digest"],
    "methylation_config_digest": contract["methylation_config_digest"],
    "container_digest": contract["container_digest"],
    "phased_prerequisite_policy": contract["phased_prerequisite_policy"],
    "outputs": {key: str(value) for key, value in sorted(output_paths.items())},
    "optional_products": {
        "html_report": {"requested": False, "available": False, "reason": "removed_from_humvar3_contract"},
        "bedmethyl_hap1": {"requested": contract["methylation_mode"] == "phased", "available": Path("methylation.hap1.bedmethyl.gz").exists()},
        "bedmethyl_hap2": {"requested": contract["methylation_mode"] == "phased", "available": Path("methylation.hap2.bedmethyl.gz").exists()},
        "bigwig_hap1": {"requested": contract["methylation_mode"] == "phased", "available": Path("methylation.hap1.5mC.bw").exists()},
        "bigwig_hap2": {"requested": contract["methylation_mode"] == "phased", "available": Path("methylation.hap2.5mC.bw").exists()},
    },
}
Path("methylation_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.methylation_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "tools": ["workflow-glue check_valid_modbam", "modkit sample-probs", "modkit pileup", "modkit bm tobigwig"],
    "container_digest": contract["container_digest"],
    "command_files": ["run-methylation.sh"],
    "input_checksums": {
        "aggregate_xam": contract["aggregate_xam_digest"],
        "haplotagged_xam": contract["haplotagged_xam_digest"],
        "methylation_config": contract["methylation_config_digest"],
    },
}
Path("methylation_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.methylation_qc.v1",
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "task_key": contract["task_key"],
    "methylation_mode": contract["methylation_mode"],
    "bedmethyl": str(output_paths["bedmethyl"]),
    "bigwig": str(output_paths["bigwig"]),
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

copies = {
    "bedmethyl": Path("methylation.bedmethyl.gz"),
    "bigwig": Path("methylation.5mC.bw"),
    "methylation_manifest": Path("methylation_manifest.json"),
    "methylation_provenance": Path("methylation_provenance.json"),
    "qc_stats": Path("qc_stats.json"),
}
for kind, source in copies.items():
    target = output_paths[kind]
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)

marker_path = Path(contract["completion_marker_path"])
marker_path.parent.mkdir(parents=True, exist_ok=True)
marker = {
    "marker_schema": "gnostikon.task_completion.v1",
    "task_key": contract["task_key"],
    "task_family": contract["task_family"],
    "status": "succeeded",
    "completed_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
    "outputs": [
        {"kind": kind, "path": str(output_paths[kind]), "required": True}
        for kind in sorted(output_paths)
    ],
    "metadata": {
        "bounded_entry": contract["entry_name"],
        "entry_schema": contract["entry_schema"],
        "sample_id": contract["sample_id"],
        "reference_id": contract["reference_id"],
        "methylation_mode": contract["methylation_mode"],
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
