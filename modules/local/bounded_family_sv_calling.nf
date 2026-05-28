process runBoundedFamilySvCallingTask {
    label "wf_human_sv"
    tag "${entry.family_id}:${entry.analysis_intent_id}:${entry.role}:${entry.sample_id}:${entry.reference_id}:${entry.task_key}"

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
        path "family_sv_calling_command.json", emit: family_sv_calling_command_json
        path "family_sv_calling_manifest.json", emit: family_sv_calling_manifest
        path "family_provenance.json", emit: family_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-family-sv-calling-contract.json <<'JSON'
${contract_json}
JSON

    export AGGREGATE_XAM="${aggregate_xam}"
    export REFERENCE_FASTA="${reference}"
    export MOSDEPTH_SUMMARY="${mosdepth_summary}"
    export TARGET_BED="${target_bed}"
    python3 - <<'PY'
import datetime
import json
import os
import shlex
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


contract = json.loads(Path("bounded-family-sv-calling-contract.json").read_text())
options = contract["structural_variant_options"]
sniffles_options = options.get("sniffles_options", {})
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
commands = {}


def add_bool_option(command, key, flag):
    if sniffles_options.get(key):
        command.append(flag)


def add_int_option(command, key, flag):
    if key in sniffles_options and sniffles_options[key] is not None:
        command.extend([flag, str(int(sniffles_options[key]))])


sniffles_cmd = [
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
    sniffles_cmd.extend(["--minsvlen", str(options["min_sv_length"])])
if options["tandem_repeats_bed"]:
    sniffles_cmd.extend(["--tandem-repeats", options["tandem_repeats_bed"]])
elif options["genome_build"]:
    tr_root = os.environ.get("WFSV_TRBED_PATH", "")
    if not tr_root:
        raise RuntimeError("WFSV_TRBED_PATH is required when structural_variant_options.genome_build selects a bundled tandem-repeat BED")
    sniffles_cmd.extend(["--tandem-repeats", f"{tr_root}/{options['genome_build']}.trf.bed"])
add_bool_option(sniffles_cmd, "mosaic", "--mosaic")
add_int_option(sniffles_cmd, "min_support", "--minsupport")
add_int_option(sniffles_cmd, "minsvlen", "--minsvlen")
sniffles_cmd.extend(["--vcf", "structural_variant.raw.vcf"])
commands["sniffles"] = sniffles_cmd
Path("sniffles.command.sh").write_text(" ".join(shlex.quote(part) for part in sniffles_cmd) + "\\n")

result = run_command(["bash", "sniffles.command.sh"], commands.setdefault("executed", []))
if result.returncode != 0:
    raise RuntimeError(f"Sniffles failed for {contract['role']}:{contract['sample_id']}: {result.stderr}")

Path("structural_variant.cleaned.vcf").write_text(
    "".join(line for line in Path("structural_variant.raw.vcf").read_text().splitlines(keepends=True) if ".:0:0:0:NULL" not in line)
)
result = run_command(["bcftools", "view", "-O", "z", "structural_variant.cleaned.vcf", "-o", "structural_variant.input.vcf.gz"], commands["executed"])
if result.returncode != 0:
    raise RuntimeError(f"bcftools view failed for {contract['role']}:{contract['sample_id']}: {result.stderr}")
result = run_command(["tabix", "-p", "vcf", "structural_variant.input.vcf.gz"], commands["executed"])
if result.returncode != 0:
    raise RuntimeError(f"tabix failed for {contract['role']}:{contract['sample_id']}: {result.stderr}")

codes = options["chromosome_codes"]
if isinstance(codes, str):
    codes = [item.strip() for item in codes.split(",") if item.strip()]
filter_cmd = [
    "get_filter_calls_command.py",
    "--bcftools_threads", str(options["threads"] if options["threads"] >= 2 else 2),
    "--target_bedfile", os.environ["TARGET_BED"],
    "--vcf", "structural_variant.input.vcf.gz",
    "--depth_summary", os.environ["MOSDEPTH_SUMMARY"],
    "--min_read_support", str(options["min_read_support"]),
    "--min_read_support_limit", str(options["min_read_support_limit"]),
]
if not options["include_all_ctgs"]:
    filter_cmd.extend(["--contigs", ",".join(codes)])
commands["filter"] = filter_cmd
result = run_command(filter_cmd, commands["executed"])
if result.returncode != 0:
    raise RuntimeError(f"filter command generation failed for {contract['role']}:{contract['sample_id']}: {result.stderr}")
Path("filter.sh").write_text(result.stdout)
result = run_command(["bash", "filter.sh"], commands["executed"])
if result.returncode != 0:
    raise RuntimeError(f"SV filter failed for {contract['role']}:{contract['sample_id']}: {result.stderr}")
Path("structural_variant.filtered.vcf").write_text(result.stdout)
result = run_command(["bcftools", "sort", "-m", "2G", "-T", "./", "-O", "z", "structural_variant.filtered.vcf", "-o", "structural_variant.vcf.gz"], commands["executed"])
if result.returncode != 0:
    raise RuntimeError(f"bcftools sort failed for {contract['role']}:{contract['sample_id']}: {result.stderr}")
result = run_command(["tabix", "-p", "vcf", "structural_variant.vcf.gz"], commands["executed"])
if result.returncode != 0:
    raise RuntimeError(f"final tabix failed for {contract['role']}:{contract['sample_id']}: {result.stderr}")

Path("family_sv_calling_command.json").write_text(json.dumps(commands, indent=2, sort_keys=True) + "\\n")

manifest = {
    "schema": "wf-human-variation.family_sv_calling_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "role": contract["role"],
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
    "aggregate_xam_digest": contract["aggregate_xam_digest"],
    "sniffles_config_digest": contract["sniffles_config_digest"],
    "container_digest": contract["container_digest"],
    "outputs": {
        "structural_variant_vcf": str(output_paths["structural_variant_vcf"]),
        "structural_variant_vcf_index": str(output_paths["structural_variant_vcf_index"]),
        "structural_variant_snf": str(output_paths["structural_variant_snf"]),
        "family_sv_calling_command_json": str(output_paths["family_sv_calling_command_json"]),
        "family_sv_calling_manifest": str(output_paths["family_sv_calling_manifest"]),
    },
}
Path("family_sv_calling_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.family_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "tool": "sniffles2",
    "container_digest": contract["container_digest"],
    "command_arguments": commands,
    "input_checksums": {
        "aggregate_xam": contract["aggregate_xam_digest"],
        "aggregate_xam_index": contract["aggregate_xam_index_digest"],
        "mosdepth_summary": contract["mosdepth_summary_digest"],
        "target_bed": contract["target_bed_digest"],
        "reference": contract["reference_digest"],
        "sniffles_config": contract["sniffles_config_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
}
Path("family_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.family_sv_calling_qc.v1",
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "role": contract["role"],
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "task_key": contract["task_key"],
    "structural_variant_vcf": str(output_paths["structural_variant_vcf"]),
    "structural_variant_snf": str(output_paths["structural_variant_snf"]),
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

for kind, source in {
    "structural_variant_vcf": Path("structural_variant.vcf.gz"),
    "structural_variant_vcf_index": Path("structural_variant.vcf.gz.tbi"),
    "structural_variant_snf": Path("structural_variant.snf"),
    "family_sv_calling_command_json": Path("family_sv_calling_command.json"),
    "family_sv_calling_manifest": Path("family_sv_calling_manifest.json"),
    "family_provenance": Path("family_provenance.json"),
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
        "family_id": contract["family_id"],
        "analysis_intent_id": contract["analysis_intent_id"],
        "role": contract["role"],
        "sample_id": contract["sample_id"],
        "reference_id": contract["reference_id"],
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
