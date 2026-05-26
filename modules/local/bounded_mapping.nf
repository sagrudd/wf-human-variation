process runBoundedMappingTask {
    label "wf_common"
    tag "${entry.sample_id}:${entry.reference_id}:${entry.task_key}"

    cpus {
        entry.mapper_options.fastq_threads +
        entry.mapper_options.map_threads +
        entry.mapper_options.sort_threads
    }
    memory { (32.GB * task.attempt) - 1.GB }
    maxRetries 1
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }

    input:
        val entry
        val contract_json
        path reads
        path reference

    output:
        path "mapped.bam", optional: true, emit: mapped_bam
        path "mapped.bam.bai", optional: true, emit: mapped_bam_index
        path "mapped.cram", optional: true, emit: mapped_cram
        path "mapped.cram.crai", optional: true, emit: mapped_cram_index
        path "alignment_metadata.json", emit: alignment_metadata
        path "runids.txt", emit: run_ids
        path "mapper_provenance.json", emit: mapper_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    def reset_cmd_body = "samtools reset -x tp,cm,s1,s2,NM,MD,AS,SA,ms,nn,ts,cg,cs,dv,de,rl"
    def fastq_cmd_body = "samtools fastq -T 1"
    def out_xam = "mapped.${entry.output_format}"
    def out_idx = "mapped.${entry.output_format}.${entry.output_index_format}"
    def view_format = entry.output_format == "cram" ? "CRAM" : "BAM"
    def map_threads = entry.mapper_options.map_threads
    def sort_threads = entry.mapper_options.sort_threads
    def fastq_threads = entry.mapper_options.fastq_threads
    def bamstats_threads = entry.mapper_options.bamstats_threads
    def preset = entry.mapper_options.minimap2_preset
    def cap_kalloc = entry.mapper_options.cap_kalloc
    def cap_sw_mem = entry.mapper_options.cap_sw_mem
    """
    set -euo pipefail

    cat > bounded-mapping-contract.json <<'JSON'
${contract_json}
JSON

    force_align=0
    if [ "${entry.input_kind}" = "ubam" ]; then
        force_align=1
    fi

    to_align=0
    workflow-glue check_sq_ref --xam ${reads} --ref ${reference} || to_align=\$?
    sq_count=\$(samtools view -H ${reads} | { grep -c '^@SQ' || [ "\$?" = "1" ]; })
    if [ "\$sq_count" = "0" ]; then
        to_align=65
    fi
    if [ "\$to_align" != "0" ] && [ "\$to_align" != "65" ]; then
        exit 1
    fi
    if [ "\$force_align" = "1" ] || [ "\$to_align" = "65" ]; then
        action="mapped"
        samtools view -H --no-PG ${reads} > reads.header
        ${reset_cmd_body} --no-PG ${reads} -o - \\
            | ${fastq_cmd_body} -@ ${fastq_threads} - \\
            | minimap2 -y -t ${map_threads} -a -x ${preset} --cap-kalloc ${cap_kalloc} --cap-sw-mem ${cap_sw_mem} \\
                ${reference} - \\
            | workflow-glue reheader_samstream reads.header \\
                 --insert \$'@PG\\tID:reset\\tPN:samtools\\tCL:${reset_cmd_body}' \\
                 --insert \$'@PG\\tID:fastq\\tPN:samtools\\tCL:${fastq_cmd_body}' \\
            | samtools sort -@ ${sort_threads} \\
                --write-index -o ${out_xam}##idx##${out_idx} \\
                -O ${entry.output_format} --reference ${reference} -
    else
        action="reused_aligned_input"
        samtools view --no-PG --reference ${reference} -O ${view_format} \\
            --write-index -o ${out_xam}##idx##${out_idx} ${reads}
    fi

    REF_PATH=${reference} workflow-glue check_mapped_reads --xam ${out_xam} > env.vars
    source env.vars
    printf '%s\\n' "\$action" > action.txt
    printf '%s\\n' "\$has_maps" > has_maps.txt

    mkdir -p bamstats_results
    REF_PATH=${reference} bamstats ${out_xam} -s ${entry.sample_id} -u \\
        -f bamstats_results/bamstats.flagstat.tsv \\
        -t ${bamstats_threads} \\
        -i bamstats_results/bamstats.runids.tsv \\
        -l bamstats_results/bamstats.basecallers.tsv \\
        > /dev/null

    awk -F '\\t' '
        NR==1 {for (i=1; i<=NF; i++) {ix[\$i] = i}}
        NR>1 && \$ix["run_id"] != "" {print \$ix["run_id"]}
    ' bamstats_results/bamstats.runids.tsv | sort -u > runids.txt

    python3 - <<'PY'
import datetime
import json
import shutil
from pathlib import Path

contract = json.loads(Path("bounded-mapping-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
action = Path("action.txt").read_text().strip()
has_mapped_reads = Path("has_maps.txt").read_text().strip() == "1"

flagstat_rows = []
flagstat_path = Path("bamstats_results/bamstats.flagstat.tsv")
if flagstat_path.exists():
    header = []
    for line_number, line in enumerate(flagstat_path.read_text().splitlines()):
        fields = line.split("\\t")
        if line_number == 0:
            header = fields
            continue
        flagstat_rows.append(dict(zip(header, fields)))

metadata = {
    "schema": "wf-human-variation.mapping_alignment_metadata.v1",
    "sample_id": contract["sample_id"],
    "task_key": contract["task_key"],
    "reference_id": contract["reference_id"],
    "input_xam": contract["input_xam"],
    "input_kind": contract["input_kind"],
    "input_digest": contract["input_digest"],
    "output_format": contract["output_format"],
    "action": action,
    "has_mapped_reads": has_mapped_reads,
    "mapped_xam": str(output_paths["mapped_xam"]),
    "mapped_xam_index": str(output_paths["mapped_xam_index"]),
}
Path("alignment_metadata.json").write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.mapping_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "mapper": contract["mapper"],
    "mapper_options": contract["mapper_options"],
    "mapper_options_digest": contract["mapper_options_digest"],
    "container_digest": contract["container_digest"],
    "command_arguments": {
        "input_kind": contract["input_kind"],
        "input_digest": contract["input_digest"],
        "reference_id": contract["reference_id"],
        "output_format": contract["output_format"],
    },
}
Path("mapper_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.mapping_qc_stats.v1",
    "sample_id": contract["sample_id"],
    "task_key": contract["task_key"],
    "reference_id": contract["reference_id"],
    "has_mapped_reads": has_mapped_reads,
    "flagstat": flagstat_rows,
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

copies = {
    "mapped_xam": Path("${out_xam}"),
    "mapped_xam_index": Path("${out_idx}"),
    "alignment_metadata": Path("alignment_metadata.json"),
    "run_ids": Path("runids.txt"),
    "mapper_provenance": Path("mapper_provenance.json"),
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
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
