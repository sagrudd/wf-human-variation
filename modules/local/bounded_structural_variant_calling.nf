process runBoundedStructuralVariantTask {
    label "wf_human_sv"
    tag "${entry.sample_id}:${entry.reference_id}:${entry.variant_mode}:${entry.task_key}"

    cpus { entry.structural_variant_options.threads }
    memory 24.GB

    input:
        val entry
        val contract_json
        path aggregate_xam
        path aggregate_xam_index
        path reference
        path reference_index
        path mosdepth_summary
        path target_bed

    output:
        path "structural_variant.vcf.gz", emit: structural_variant_vcf
        path "structural_variant.vcf.gz.tbi", emit: structural_variant_vcf_index
        path "structural_variant.snf", emit: structural_variant_snf
        path "variant_calling_manifest.json", emit: variant_calling_manifest
        path "variant_calling_provenance.json", emit: variant_calling_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-structural-variant-contract.json <<'JSON'
${contract_json}
JSON

    export AGGREGATE_XAM="${aggregate_xam}"
    export REFERENCE_FASTA="${reference}"
    export MOSDEPTH_SUMMARY="${mosdepth_summary}"
    export TARGET_BED="${target_bed}"
    python3 - <<'PY'
import json
import os
import shlex
from pathlib import Path

contract = json.loads(Path("bounded-structural-variant-contract.json").read_text())
options = contract["structural_variant_options"]
sniffles_options = options.get("sniffles_options", {})

def add_bool_option(command, key, flag):
    if sniffles_options.get(key):
        command.append(flag)

def add_int_option(command, key, flag):
    if key in sniffles_options and sniffles_options[key] is not None:
        command.extend([flag, str(int(sniffles_options[key]))])

cmd = [
    "sniffles",
    "--threads", str(options["threads"]),
    "--sample-id", contract["sample_id"],
    "--output-rnames",
    "--cluster-merge-pos", str(options["cluster_merge_pos"]),
    "--input", os.environ["AGGREGATE_XAM"],
    "--reference", os.environ["REFERENCE_FASTA"],
    "--input-exclude-flags", "2308",
    "--snf", "structural_variant.snf",
]
if int(options["min_sv_length"]) > 0 and "minsvlen" not in sniffles_options:
    cmd.extend(["--minsvlen", str(options["min_sv_length"])])
if options["tandem_repeats_bed"]:
    cmd.extend(["--tandem-repeats", options["tandem_repeats_bed"]])
elif options["genome_build"]:
    tr_root = os.environ.get("WFSV_TRBED_PATH", "")
    if not tr_root:
        raise RuntimeError("WFSV_TRBED_PATH is required when structural_variant_options.genome_build selects a bundled tandem-repeat BED")
    cmd.extend(["--tandem-repeats", f"{tr_root}/{options['genome_build']}.trf.bed"])
add_bool_option(cmd, "mosaic", "--mosaic")
add_int_option(cmd, "min_support", "--minsupport")
add_int_option(cmd, "minsvlen", "--minsvlen")
cmd.extend(["--vcf", "structural_variant.raw.vcf"])

Path("sniffles.command.sh").write_text(" ".join(shlex.quote(part) for part in cmd) + "\\n")
Path("sniffles.command.json").write_text(json.dumps(cmd, indent=2, sort_keys=True) + "\\n")
PY

    bash sniffles.command.sh
    sed '/.:0:0:0:NULL/d' structural_variant.raw.vcf > structural_variant.cleaned.vcf
    bcftools view -O z structural_variant.cleaned.vcf > structural_variant.input.vcf.gz
    tabix -p vcf structural_variant.input.vcf.gz

    python3 - <<'PY'
import json
import os
import shlex
from pathlib import Path

contract = json.loads(Path("bounded-structural-variant-contract.json").read_text())
options = contract["structural_variant_options"]
codes = options["chromosome_codes"]
if isinstance(codes, str):
    codes = [item.strip() for item in codes.split(",") if item.strip()]
ctgs_filter = "" if options["include_all_ctgs"] else "--contigs " + ",".join(codes)
command = [
    "get_filter_calls_command.py",
    "--bcftools_threads", str(options["threads"] if options["threads"] >= 2 else 2),
    "--target_bedfile", os.environ["TARGET_BED"],
    "--vcf", "structural_variant.input.vcf.gz",
    "--depth_summary", os.environ["MOSDEPTH_SUMMARY"],
    "--min_read_support", str(options["min_read_support"]),
    "--min_read_support_limit", str(options["min_read_support_limit"]),
]
if ctgs_filter:
    command.extend(ctgs_filter.split())
script = " ".join(shlex.quote(part) for part in command)
Path("filter.command.sh").write_text(script + " > filter.sh\\n")
Path("filter.command.json").write_text(json.dumps(command, indent=2, sort_keys=True) + "\\n")
PY

    bash filter.command.sh
    bash filter.sh > structural_variant.filtered.vcf
    bcftools sort -m 2G -T ./ -O z structural_variant.filtered.vcf > structural_variant.vcf.gz
    tabix -p vcf structural_variant.vcf.gz

    python3 - <<'PY'
import datetime
import json
import shutil
from pathlib import Path

contract = json.loads(Path("bounded-structural-variant-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
sniffles_command = json.loads(Path("sniffles.command.json").read_text())
filter_command = json.loads(Path("filter.command.json").read_text())

deferred_products = {
    "sv_benchmark": {"requested": False, "available": False, "reason": "deferred_machine_readable_evaluation_contract"},
    "annotated_sv_vcf": {"requested": False, "available": False, "reason": "deferred_bounded_mode"},
    "phased_sv_vcf": {"requested": False, "available": False, "reason": "deferred_bounded_mode"},
}

manifest = {
    "schema": "wf-human-variation.variant_calling_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "variant_mode": contract["variant_mode"],
    "aggregate_xam": contract["aggregate_xam"],
    "aggregate_xam_digest": contract["aggregate_xam_digest"],
    "variant_config_digest": contract["variant_config_digest"],
    "container_digest": contract["container_digest"],
    "outputs": {
        "structural_variant_vcf": str(output_paths["structural_variant_vcf"]),
        "structural_variant_vcf_index": str(output_paths["structural_variant_vcf_index"]),
        "structural_variant_snf": str(output_paths["structural_variant_snf"]),
    },
    "optional_products": deferred_products,
}
Path("variant_calling_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.variant_calling_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "tool": "sniffles2",
    "container_digest": contract["container_digest"],
    "command_arguments": {
        "sniffles": sniffles_command,
        "filter": filter_command,
        "sort_index": ["bcftools", "sort", "tabix"],
    },
    "input_checksums": {
        "aggregate_xam": contract["aggregate_xam_digest"],
        "variant_config": contract["variant_config_digest"],
    },
}
Path("variant_calling_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.variant_calling_qc.v1",
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "task_key": contract["task_key"],
    "variant_mode": contract["variant_mode"],
    "structural_variant_vcf": str(output_paths["structural_variant_vcf"]),
    "optional_products": deferred_products,
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

copies = {
    "structural_variant_vcf": Path("structural_variant.vcf.gz"),
    "structural_variant_vcf_index": Path("structural_variant.vcf.gz.tbi"),
    "structural_variant_snf": Path("structural_variant.snf"),
    "variant_calling_manifest": Path("variant_calling_manifest.json"),
    "variant_calling_provenance": Path("variant_calling_provenance.json"),
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
        "variant_mode": contract["variant_mode"],
        "optional_products": deferred_products,
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
