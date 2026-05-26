process runBoundedSampleAggregationTask {
    label "wf_common"
    tag "${entry.sample_id}:${entry.reference_id}:${entry.task_key}"

    cpus {
        entry.aggregation_options.view_threads +
        entry.aggregation_options.bamstats_threads +
        entry.aggregation_options.mosdepth_threads
    }
    memory { (16.GB * task.attempt) - 1.GB }
    maxRetries 1
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }

    input:
        val entry
        val contract_json
        path mapped_xam
        path mapped_xam_index
        path reference
        path reference_index

    output:
        path "aggregate.bam", optional: true, emit: aggregate_bam
        path "aggregate.bam.bai", optional: true, emit: aggregate_bam_index
        path "aggregate.cram", optional: true, emit: aggregate_cram
        path "aggregate.cram.crai", optional: true, emit: aggregate_cram_index
        path "readstats.tsv.gz", emit: readstats
        path "flagstat.tsv", emit: flagstat
        path "runids.txt", emit: run_ids
        path "basecallers.txt", emit: basecallers
        path "mosdepth.summary.txt", emit: mosdepth_summary
        path "mosdepth.regions.bed.gz", emit: mosdepth_regions
        path "mosdepth.global.dist.txt", emit: mosdepth_distribution
        path "mosdepth.thresholds.bed.gz", emit: mosdepth_thresholds
        path "coverage_state.json", emit: coverage_state
        path "qc_stats.json", emit: qc_stats
        path "aggregation_manifest.json", emit: aggregation_manifest

    script:
    def out_xam = "aggregate.${entry.output_format}"
    def out_idx = "aggregate.${entry.output_format}.${entry.output_index_format}"
    def view_format = entry.output_format == "cram" ? "CRAM" : "BAM"
    def view_threads = entry.aggregation_options.view_threads
    def bamstats_threads = entry.aggregation_options.bamstats_threads
    def mosdepth_threads = entry.aggregation_options.mosdepth_threads
    def mosdepth_thresholds = entry.aggregation_options.mosdepth_thresholds
    """
    set -euo pipefail

    cat > bounded-sample-aggregation-contract.json <<'JSON'
${contract_json}
JSON

    samtools view --no-PG --threads ${view_threads} --reference ${reference} -O ${view_format} \\
        --write-index -o ${out_xam}##idx##${out_idx} ${mapped_xam}

    awk 'BEGIN {OFS="\\t"} {print \$1, 0, \$2}' ${reference_index} > all-chromosomes.bed
    {
        cat all-chromosomes.bed
        printf '*\\t0\\t0\\n'
    } > readstats-targets.bed

    mkdir -p bamstats_results
    samtools view --threads ${view_threads} -u -h --regions-file readstats-targets.bed ${out_xam} \\
        | REF_PATH=${reference} bamstats - -s ${entry.sample_id} -u \\
            -f flagstat.tsv \\
            -t ${bamstats_threads} \\
            -i bamstats_results/bamstats.runids.tsv \\
            -l bamstats_results/bamstats.basecallers.tsv \\
        | gzip > readstats.tsv.gz

    awk -F '\\t' '
        NR==1 {for (i=1; i<=NF; i++) {ix[\$i] = i}}
        NR>1 && \$ix["run_id"] != "" {print \$ix["run_id"]}
    ' bamstats_results/bamstats.runids.tsv | sort -u > runids.txt

    awk -F '\\t' '
        NR==1 {for (i=1; i<=NF; i++) {ix[\$i] = i}}
        NR>1 && \$ix["basecaller"] != "" {print \$ix["basecaller"]}
    ' bamstats_results/bamstats.basecallers.tsv | sort -u > basecallers.txt

    REF_PATH=${reference} workflow-glue check_mapped_reads --xam ${out_xam} > env.vars
    source env.vars
    printf '%s\\n' "\$has_maps" > has_maps.txt

    mosdepth -x -t ${mosdepth_threads} -b all-chromosomes.bed \\
        --thresholds ${mosdepth_thresholds} \\
        --no-per-base \\
        mosdepth ${out_xam}

    python3 - <<'PY'
import datetime
import json
import shutil
from pathlib import Path


def read_lines(path):
    if not path.exists():
        return []
    return [line.strip() for line in path.read_text().splitlines() if line.strip()]


def parse_table(path):
    if not path.exists():
        return []
    lines = path.read_text().splitlines()
    if not lines:
        return []
    header = lines[0].split("\\t")
    return [dict(zip(header, line.split("\\t"))) for line in lines[1:] if line.strip()]


def parse_mosdepth_summary(path):
    rows = parse_table(path)
    for row in rows:
        if row.get("chrom") == "total_region":
            return row
    return rows[-1] if rows else {}


contract = json.loads(Path("bounded-sample-aggregation-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
has_mapped_reads = Path("has_maps.txt").read_text().strip() == "1"
summary_row = parse_mosdepth_summary(Path("mosdepth.summary.txt"))
mean_depth = float(summary_row.get("mean", "0") or 0)
coverage_min_depth = float(contract["aggregation_options"]["coverage_min_depth"])
coverage_passed = has_mapped_reads and mean_depth >= coverage_min_depth
coverage_status = "coverage_passed" if coverage_passed else "rejected_low_coverage"

coverage_state = {
    "schema": "wf-human-variation.coverage_state.v1",
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "task_key": contract["task_key"],
    "state": coverage_status,
    "has_mapped_reads": has_mapped_reads,
    "mean_depth": mean_depth,
    "minimum_depth": coverage_min_depth,
    "mosdepth_summary": str(output_paths["mosdepth_summary"]),
}
Path("coverage_state.json").write_text(json.dumps(coverage_state, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.sample_aggregation_qc.v1",
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "task_key": contract["task_key"],
    "coverage_state": coverage_state,
    "flagstat": parse_table(Path("flagstat.tsv")),
    "run_ids": read_lines(Path("runids.txt")),
    "basecallers": read_lines(Path("basecallers.txt")),
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

manifest = {
    "schema": "wf-human-variation.sample_aggregation_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "sample_id": contract["sample_id"],
    "reference_id": contract["reference_id"],
    "mapped_xam": contract["mapped_xam"],
    "mapped_xam_digest": contract["mapped_xam_digest"],
    "reference_fasta": contract["reference_fasta"],
    "aggregation_config_digest": contract["aggregation_config_digest"],
    "coverage_config_digest": contract["coverage_config_digest"],
    "coverage_state": coverage_state,
    "container_digest": contract["container_digest"],
    "output_format": contract["output_format"],
    "outputs": {key: str(path) for key, path in output_paths.items()},
}
Path("aggregation_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

copies = {
    "aggregate_xam": Path("${out_xam}"),
    "aggregate_xam_index": Path("${out_idx}"),
    "readstats": Path("readstats.tsv.gz"),
    "flagstat": Path("flagstat.tsv"),
    "run_ids": Path("runids.txt"),
    "basecallers": Path("basecallers.txt"),
    "mosdepth_summary": Path("mosdepth.summary.txt"),
    "mosdepth_regions": Path("mosdepth.regions.bed.gz"),
    "mosdepth_distribution": Path("mosdepth.global.dist.txt"),
    "mosdepth_thresholds": Path("mosdepth.thresholds.bed.gz"),
    "coverage_state": Path("coverage_state.json"),
    "qc_stats": Path("qc_stats.json"),
    "aggregation_manifest": Path("aggregation_manifest.json"),
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
        "coverage_state": coverage_status,
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
