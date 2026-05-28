process runBoundedSomaticQcTask {
    label "somatic_qc"
    tag "${entry.analysis_intent_id}:${entry.reference_id}:${entry.task_key}"

    cpus 1
    memory { 4.GB * task.attempt }
    maxRetries 1
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }

    input:
        val entry
        val contract_json
        path tumour_regions
        path normal_or_control_regions
        path reference
        path target_bed

    output:
        path "${entry.analysis_intent_id}.shared-callable.bed.gz", emit: somatic_shared_regions_bed
        path "somatic_rejected_regions_summary.tsv", emit: somatic_rejected_regions_summary
        path "somatic_qc_manifest.json", emit: somatic_qc_manifest
        path "somatic_qc_metrics.json", emit: somatic_qc_metrics
        path "somatic_provenance.json", emit: somatic_provenance

    script:
    """
    set -euo pipefail

    cat > bounded-somatic-qc-contract.json <<'JSON'
${contract_json}
JSON

    export TUMOUR_REGIONS="${tumour_regions}"
    export NORMAL_OR_CONTROL_REGIONS="${normal_or_control_regions}"
    export REFERENCE_FASTA="${reference}"
    export TARGET_BED="${target_bed}"
    python3 - <<'PY'
import datetime
import gzip
import hashlib
import json
import os
import shutil
from pathlib import Path


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


def open_text(path):
    path = Path(path)
    if path.suffix == ".gz":
        return gzip.open(path, "rt")
    return path.open()


def read_bed(path):
    intervals = {}
    with open_text(path) as handle:
        for line in handle:
            if not line.strip() or line.startswith("#"):
                continue
            fields = line.rstrip("\\n").split("\\t")
            if len(fields) < 3:
                continue
            chrom = fields[0]
            start = int(fields[1])
            end = int(fields[2])
            if end > start:
                intervals.setdefault(chrom, []).append((start, end))
    return {chrom: merge_ranges(ranges) for chrom, ranges in intervals.items()}


def merge_ranges(ranges):
    merged = []
    for start, end in sorted(ranges):
        if not merged or start > merged[-1][1]:
            merged.append([start, end])
        else:
            merged[-1][1] = max(merged[-1][1], end)
    return [(start, end) for start, end in merged]


def intersect_two(left, right):
    output = {}
    for chrom in sorted(set(left) & set(right)):
        i = 0
        j = 0
        merged = []
        left_ranges = left[chrom]
        right_ranges = right[chrom]
        while i < len(left_ranges) and j < len(right_ranges):
            start = max(left_ranges[i][0], right_ranges[j][0])
            end = min(left_ranges[i][1], right_ranges[j][1])
            if end > start:
                merged.append((start, end))
            if left_ranges[i][1] < right_ranges[j][1]:
                i += 1
            else:
                j += 1
        if merged:
            output[chrom] = merge_ranges(merged)
    return output


def bed_size(intervals):
    return sum(end - start for ranges in intervals.values() for start, end in ranges)


def optional_target_path(contract):
    if not contract.get("target_bed"):
        return ""
    staged = Path(os.environ["TARGET_BED"])
    if not staged.exists():
        raise FileNotFoundError(f"target_bed was declared but does not exist in the work directory: {staged}")
    return str(staged)


def write_bed_gz(path, intervals):
    with gzip.open(path, "wt") as handle:
        for chrom in sorted(intervals):
            for start, end in intervals[chrom]:
                handle.write(f"{chrom}\\t{start}\\t{end}\\n")


def copy_output(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def sha256_file(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


contract = json.loads(Path("bounded-somatic-qc-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
target_path = optional_target_path(contract)

tumour = read_bed(os.environ["TUMOUR_REGIONS"])
normal_or_control = read_bed(os.environ["NORMAL_OR_CONTROL_REGIONS"])
shared_before_target = intersect_two(tumour, normal_or_control)
if target_path:
    target = read_bed(target_path)
    shared = intersect_two(shared_before_target, target)
else:
    shared = shared_before_target

shared_bed = Path(f"{contract['analysis_intent_id']}.shared-callable.bed.gz")
write_bed_gz(shared_bed, shared)

sizes = {
    "tumour_callable_bp": bed_size(tumour),
    "normal_or_control_callable_bp": bed_size(normal_or_control),
    "shared_before_target_bp": bed_size(shared_before_target),
    "shared_callable_bp": bed_size(shared),
}
sizes["tumour_rejected_not_shared_bp"] = max(0, sizes["tumour_callable_bp"] - sizes["shared_before_target_bp"])
sizes["normal_or_control_rejected_not_shared_bp"] = max(
    0,
    sizes["normal_or_control_callable_bp"] - sizes["shared_before_target_bp"],
)
sizes["target_excluded_bp"] = max(0, sizes["shared_before_target_bp"] - sizes["shared_callable_bp"])

summary_path = Path("somatic_rejected_regions_summary.tsv")
summary_path.write_text(
    "reason\\tbases\\n"
    + f"tumour_not_callable_in_{contract['normal_or_control_role']}\\t{sizes['tumour_rejected_not_shared_bp']}\\n"
    + f"{contract['normal_or_control_role']}_not_callable_in_tumour\\t{sizes['normal_or_control_rejected_not_shared_bp']}\\n"
    + f"target_bed_excluded\\t{sizes['target_excluded_bp']}\\n"
)
shared_bed_sha256 = sha256_file(shared_bed)
summary_sha256 = sha256_file(summary_path)

shared_region_state = {
    "state": "shared_region_empty" if sizes["shared_callable_bp"] == 0 else "ready",
    "asset_kind": "shared_callable_regions_bed",
    "path": str(output_paths["somatic_shared_regions_bed"]),
    "checksum": shared_bed_sha256,
    "sha256": shared_bed_sha256,
    "reference_id": contract["reference_id"],
    "genome_build": contract["reference_genome_build"] or None,
    "rejected_regions_summary_path": str(output_paths["somatic_rejected_regions_summary"]),
    "rejected_regions_summary_checksum": summary_sha256,
    "rejected_regions_summary_sha256": summary_sha256,
    "shared_callable_bp": sizes["shared_callable_bp"],
    "tumour_coverage_bed_id": contract.get("tumour_mosdepth_regions_artefact_id") or contract["tumour_mosdepth_regions"],
    "normal_or_control_coverage_bed_id": contract.get("normal_or_control_mosdepth_regions_artefact_id")
    or contract["normal_or_control_mosdepth_regions"],
}

manifest = {
    "schema": "wf-human-variation.somatic_qc_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"] or None,
    "tumour_sample_id": contract["tumour_sample_id"],
    "normal_or_control_sample_id": contract["normal_or_control_sample_id"],
    "normal_or_control_role": contract["normal_or_control_role"],
    "reference_id": contract["reference_id"],
    "reference_genome_build": contract["reference_genome_build"] or None,
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"] or None,
    "target_bed": contract["target_bed"] or None,
    "target_bed_digest": contract["target_bed_digest"] or None,
    "coverage_thresholds_digest": contract["coverage_thresholds_digest"],
    "somatic_qc_config_digest": contract["somatic_qc_config_digest"],
    "container_digest": contract["container_digest"],
    "shared_region_state": shared_region_state,
    "outputs": {
        "somatic_shared_regions_bed": str(output_paths["somatic_shared_regions_bed"]),
        "somatic_rejected_regions_summary": str(output_paths["somatic_rejected_regions_summary"]),
        "somatic_qc_manifest": str(output_paths["somatic_qc_manifest"]),
        "somatic_qc_metrics": str(output_paths["somatic_qc_metrics"]),
        "somatic_provenance": str(output_paths["somatic_provenance"]),
    },
    "removed_products": {
        "html_report": {"available": False, "reason": "removed_from_humvar3_contract"},
        "legacy_pairwise_bed_flow": {"available": False, "reason": "controller_owned_shared_region_state"},
    },
}
Path("somatic_qc_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

metrics = {
    "schema": "wf-human-variation.somatic_qc_metrics.v1",
    "analysis_intent_id": contract["analysis_intent_id"],
    "task_key": contract["task_key"],
    "interval_counts": {
        "tumour": sum(len(ranges) for ranges in tumour.values()),
        "normal_or_control": sum(len(ranges) for ranges in normal_or_control.values()),
        "shared": sum(len(ranges) for ranges in shared.values()),
    },
    "bases": sizes,
}
Path("somatic_qc_metrics.json").write_text(json.dumps(metrics, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.somatic_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "tool": "python_interval_intersection",
    "container_digest": contract["container_digest"],
    "command_arguments": {
        "operation": "tumour_intersect_normal_or_control_intersect_optional_target",
        "target_bed": target_path or None,
    },
    "input_checksums": {
        "tumour_mosdepth_regions": contract["tumour_mosdepth_regions_digest"],
        "normal_or_control_mosdepth_regions": contract["normal_or_control_mosdepth_regions_digest"],
        "target_bed": contract["target_bed_digest"] or None,
        "reference": contract["reference_digest"],
        "coverage_thresholds": contract["coverage_thresholds_digest"],
        "somatic_qc_config": contract["somatic_qc_config_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"] or None,
}
Path("somatic_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

for kind, source in {
    "somatic_shared_regions_bed": shared_bed,
    "somatic_rejected_regions_summary": summary_path,
    "somatic_qc_manifest": Path("somatic_qc_manifest.json"),
    "somatic_qc_metrics": Path("somatic_qc_metrics.json"),
    "somatic_provenance": Path("somatic_provenance.json"),
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
        "pair_id": contract["pair_id"] or None,
        "reference_id": contract["reference_id"],
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
