process runBoundedSmallVariantTask {
    label "wf_human_snp"
    tag "${entry.sample_id}:${entry.reference_id}:${entry.variant_mode}:${entry.task_key}"

    cpus { entry.variant_options.threads }
    memory { (32.GB * task.attempt) - 1.GB }
    maxRetries 1
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }

    input:
        val entry
        val contract_json
        path aggregate_xam
        path aggregate_xam_index
        path reference
        path reference_index
        path clair3_model

    output:
        path "snp.vcf.gz", emit: snp_vcf
        path "snp.vcf.gz.tbi", emit: snp_vcf_index
        path "snp.gvcf.gz", optional: true, emit: snp_gvcf
        path "snp.gvcf.gz.tbi", optional: true, emit: snp_gvcf_index
        path "variant_calling_manifest.json", emit: variant_calling_manifest
        path "variant_calling_provenance.json", emit: variant_calling_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-variant-calling-contract.json <<'JSON'
${contract_json}
JSON

    AGGREGATE_XAM=${aggregate_xam} \\
    REFERENCE_FASTA=${reference} \\
    CLAIR3_MODEL=${clair3_model} \\
    python3 - <<'PY'
import json
import os
import shlex
from pathlib import Path

contract = json.loads(Path("bounded-variant-calling-contract.json").read_text())
options = contract["variant_options"]
snp_min_af = "0.0" if options["genotyping_vcf"] else str(options["snp_min_af"])
indel_min_af = "0.0" if options["genotyping_vcf"] else str(options["indel_min_af"])
cmd = [
    "run_clair3.sh",
    "--bam_fn", os.environ["AGGREGATE_XAM"],
    "--ref_fn", os.environ["REFERENCE_FASTA"],
    "--output", "clair3_output",
    "--platform", "ont",
    "--sample_name", contract["sample_id"],
    "--model_path", os.environ["CLAIR3_MODEL"],
    "--threads", str(options["threads"]),
    "--chunk_num", str(options["chunk_num"]),
    "--chunk_size", str(options["chunk_size"]),
    "--qual", str(options["min_qual"]),
    "--var_pct_full", str(options["var_pct_full"]),
    "--ref_pct_full", str(options["ref_pct_full"]),
    "--snp_min_af", snp_min_af,
    "--indel_min_af", indel_min_af,
    "--min_contig_size", str(options["min_contig_size"]),
    "--include_all_ctgs", str(options["include_all_ctgs"]).lower(),
]
if options["ctg_name"]:
    cmd.extend(["--ctg_name", options["ctg_name"]])
if options["target_bed"]:
    cmd.extend(["--bed_fn", options["target_bed"]])
if options["genotyping_vcf"]:
    cmd.extend(["--vcf_fn", options["genotyping_vcf"]])
if options["emit_gvcf"]:
    cmd.append("--gvcf")

Path("run-clair3.command.sh").write_text(" ".join(shlex.quote(part) for part in cmd) + "\\n")
Path("run-clair3.command.json").write_text(json.dumps(cmd, indent=2, sort_keys=True) + "\\n")
PY

    bash run-clair3.command.sh

    python3 - <<'PY'
import datetime
import json
import shutil
from pathlib import Path

contract = json.loads(Path("bounded-variant-calling-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
options = contract["variant_options"]
command = json.loads(Path("run-clair3.command.json").read_text())

vcf_source = Path("clair3_output/merge_output.vcf.gz")
vcf_index_source = Path("clair3_output/merge_output.vcf.gz.tbi")
if not vcf_source.exists() or not vcf_index_source.exists():
    raise FileNotFoundError("Clair3 did not produce merge_output.vcf.gz and index")

shutil.copy2(vcf_source, "snp.vcf.gz")
shutil.copy2(vcf_index_source, "snp.vcf.gz.tbi")

gvcf_source = Path("clair3_output/merge_output.gvcf.gz")
gvcf_index_source = Path("clair3_output/merge_output.gvcf.gz.tbi")
gvcf_available = gvcf_source.exists() and gvcf_index_source.exists()
if options["emit_gvcf"] and not gvcf_available:
    raise FileNotFoundError("Clair3 GVCF mode was requested but merge_output.gvcf.gz and index were not produced")
if gvcf_available:
    shutil.copy2(gvcf_source, "snp.gvcf.gz")
    shutil.copy2(gvcf_index_source, "snp.gvcf.gz.tbi")

optional_products = {
    "snp_gvcf": {
        "requested": bool(options["emit_gvcf"]),
        "available": gvcf_available,
        "path": str(gvcf_source) if gvcf_available else None,
    },
    "phased_snp_vcf": {"requested": False, "available": False, "reason": "deferred_bounded_mode"},
    "haplotagged_xam": {"requested": False, "available": False, "reason": "deferred_bounded_mode"},
    "haplotagged_contig_bams": {"requested": False, "available": False, "reason": "deferred_bounded_mode"},
    "sv_refined_snp_vcf": {"requested": False, "available": False, "reason": "deferred_bounded_mode"},
    "annotated_snp_vcf": {"requested": False, "available": False, "reason": "deferred_bounded_mode"},
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
    "clair3_model_digest": contract["clair3_model_digest"],
    "variant_config_digest": contract["variant_config_digest"],
    "container_digest": contract["container_digest"],
    "outputs": {
        "snp_vcf": str(output_paths["snp_vcf"]),
        "snp_vcf_index": str(output_paths["snp_vcf_index"]),
    },
    "optional_products": optional_products,
}
Path("variant_calling_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.variant_calling_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "tool": "clair3",
    "container_digest": contract["container_digest"],
    "command_arguments": command,
    "input_checksums": {
        "aggregate_xam": contract["aggregate_xam_digest"],
        "clair3_model": contract["clair3_model_digest"],
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
    "snp_vcf": str(output_paths["snp_vcf"]),
    "optional_products": optional_products,
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

copies = {
    "snp_vcf": Path("snp.vcf.gz"),
    "snp_vcf_index": Path("snp.vcf.gz.tbi"),
    "variant_calling_manifest": Path("variant_calling_manifest.json"),
    "variant_calling_provenance": Path("variant_calling_provenance.json"),
    "qc_stats": Path("qc_stats.json"),
}
if "snp_gvcf" in output_paths:
    copies["snp_gvcf"] = Path("snp.gvcf.gz")
    copies["snp_gvcf_index"] = Path("snp.gvcf.gz.tbi")
    manifest["outputs"]["snp_gvcf"] = str(output_paths["snp_gvcf"])
    manifest["outputs"]["snp_gvcf_index"] = str(output_paths["snp_gvcf_index"])
    Path("variant_calling_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")
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
        "optional_products": optional_products,
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
