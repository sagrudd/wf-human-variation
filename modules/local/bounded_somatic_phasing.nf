process runBoundedSomaticPhasingTask {
    label "somatic_phasing"
    tag "${entry.analysis_intent_id}:${entry.sample_role}:${entry.sample_id}:${entry.task_key}"

    cpus 2
    memory { 4.GB * task.attempt }
    maxRetries 1
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }

    input:
        val entry
        val contract_json
        path input_vcf
        path input_vcf_index
        path role_aggregate_xam
        path role_aggregate_xam_index
        path reference
        path reference_index

    output:
        path "selected_heterozygous_sites.vcf.gz", emit: selected_heterozygous_sites
        path "somatic_phased.vcf.gz", emit: somatic_phased_vcf
        path "somatic_phased.vcf.gz.tbi", emit: somatic_phased_vcf_index
        path "somatic_phasing_manifest.json", emit: somatic_phasing_manifest
        path "somatic_phasing_command.json", emit: somatic_phasing_command_json
        path "somatic_phasing_state.json", emit: somatic_phasing_state
        path "somatic_provenance.json", emit: somatic_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-somatic-phasing-contract.json <<'JSON'
${contract_json}
JSON

    cp "${input_vcf}" input.vcf.gz
    cp "${input_vcf_index}" input.vcf.gz.tbi
    export ROLE_XAM="${role_aggregate_xam}"
    export REFERENCE_FASTA="${reference}"
    python3 - <<'PY'
import datetime
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


def run_command(cmd, commands):
    commands.append(cmd)
    return subprocess.run(cmd, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def copy_output(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


contract = json.loads(Path("bounded-somatic-phasing-contract.json").read_text())
options = contract["somatic_phasing_options"]
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
commands = []
state = "completed"
failure = None

whatshap_version = "unknown"
version_result = run_command(["whatshap", "--version"], commands)
if version_result.returncode == 0 and version_result.stdout.strip():
    whatshap_version = version_result.stdout.strip().splitlines()[0]

select_cmd = [
    "bcftools",
    "view",
    "-s",
    contract["sample_id"],
    "-i",
    'GT="het"',
    "-O",
    "z",
    "-o",
    "selected_heterozygous_sites.vcf.gz",
    "input.vcf.gz",
]
if options["only_snvs"]:
    select_cmd[2:2] = ["--types", "snps"]
result = run_command(select_cmd, commands)
if result.returncode != 0:
    state = "failed"
    failure = {"stage": "select_heterozygous_sites", "exit_code": result.returncode, "stderr": result.stderr}
else:
    result = run_command(["tabix", "-p", "vcf", "selected_heterozygous_sites.vcf.gz"], commands)
    if result.returncode != 0:
        state = "failed"
        failure = {"stage": "index_selected_heterozygous_sites", "exit_code": result.returncode, "stderr": result.stderr}

het_count = 0
if state != "failed":
    result = run_command(["bcftools", "view", "-H", "selected_heterozygous_sites.vcf.gz"], commands)
    if result.returncode == 0:
        het_count = len([line for line in result.stdout.splitlines() if line.strip()])

if state != "failed" and not options["enabled"]:
    state = "skipped_disabled"
    shutil.copy2("input.vcf.gz", "somatic_phased.vcf.gz")
    shutil.copy2("input.vcf.gz.tbi", "somatic_phased.vcf.gz.tbi")
elif state != "failed" and het_count == 0:
    state = "skipped_no_heterozygous_sites"
    shutil.copy2("input.vcf.gz", "somatic_phased.vcf.gz")
    shutil.copy2("input.vcf.gz.tbi", "somatic_phased.vcf.gz.tbi")
elif state != "failed":
    phased_contigs = []
    for contig in options["contigs"]:
        cmd = [
            "whatshap",
            "phase",
            "--output",
            f"phased_{contig}.vcf",
            "--chromosome",
            contig,
            "--reference",
            "REFERENCE_FASTA_PLACEHOLDER",
            "selected_heterozygous_sites.vcf.gz",
            "ROLE_XAM_PLACEHOLDER",
        ]
        cmd[cmd.index("REFERENCE_FASTA_PLACEHOLDER")] = str(Path(os.environ["REFERENCE_FASTA"]))
        cmd[cmd.index("ROLE_XAM_PLACEHOLDER")] = str(Path(os.environ["ROLE_XAM"]))
        result = run_command(cmd, commands)
        if result.returncode != 0:
            state = "failed"
            failure = {"stage": "whatshap_phase", "contig": contig, "exit_code": result.returncode, "stderr": result.stderr}
            break
        result = run_command(["bash", "-c", f"bgzip -c phased_{contig}.vcf > phased_{contig}.vcf.gz"], commands)
        if result.returncode != 0:
            state = "failed"
            failure = {"stage": "compress_phased_contig", "contig": contig, "exit_code": result.returncode, "stderr": result.stderr}
            break
        result = run_command(["tabix", "-p", "vcf", f"phased_{contig}.vcf.gz"], commands)
        if result.returncode != 0:
            state = "failed"
            failure = {"stage": "index_phased_contig", "contig": contig, "exit_code": result.returncode, "stderr": result.stderr}
            break
        phased_contigs.append(f"phased_{contig}.vcf.gz")
    if state != "failed":
        concat_cmd = ["bash", "-o", "pipefail", "-c", "bcftools concat -O u " + " ".join(phased_contigs) + " | bcftools sort -O z -o somatic_phased.vcf.gz"]
        result = run_command(concat_cmd, commands)
        if result.returncode != 0:
            state = "failed"
            failure = {"stage": "concat_phased_contigs", "exit_code": result.returncode, "stderr": result.stderr}
        else:
            result = run_command(["tabix", "-p", "vcf", "somatic_phased.vcf.gz"], commands)
            if result.returncode != 0:
                state = "failed"
                failure = {"stage": "index_somatic_phased_vcf", "exit_code": result.returncode, "stderr": result.stderr}

Path("somatic_phasing_command.json").write_text(json.dumps({
    "schema": "wf-human-variation.somatic_phasing_command.v1",
    "task_key": contract["task_key"],
    "tool": "whatshap",
    "structured_options": options,
    "commands": commands,
}, indent=2, sort_keys=True) + "\\n")

Path("somatic_phasing_state.json").write_text(json.dumps({
    "schema": "wf-human-variation.somatic_phasing_state.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "sample_id": contract["sample_id"],
    "sample_role": contract["sample_role"],
    "reference_id": contract["reference_id"],
    "state": state,
    "failure": failure,
    "heterozygous_site_count": het_count,
    "phasing_policy": {"tool": options["tool"], "enabled": options["enabled"], "only_snvs": options["only_snvs"]},
}, indent=2, sort_keys=True) + "\\n")

Path("somatic_phasing_manifest.json").write_text(json.dumps({
    "schema": "wf-human-variation.somatic_phasing_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"] or None,
    "sample_id": contract["sample_id"],
    "sample_role": contract["sample_role"],
    "reference_id": contract["reference_id"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"] or None,
    "state": state,
    "whatshap_version": whatshap_version,
    "phasing_config_digest": contract["phasing_config_digest"],
    "phasing_options_digest": contract["phasing_options_digest"],
    "reference_digest": contract["reference_digest"],
    "container_digest": contract["container_digest"],
    "outputs": {key: str(value) for key, value in output_paths.items()},
}, indent=2, sort_keys=True) + "\\n")

Path("somatic_provenance.json").write_text(json.dumps({
    "schema": "wf-human-variation.somatic_provenance.v1",
    "task_family": contract["task_family"],
    "task_stage": "somatic_phasing",
    "task_key": contract["task_key"],
    "tool": "whatshap",
    "tool_version": whatshap_version,
    "container_digest": contract["container_digest"],
    "command_arguments": json.loads(Path("somatic_phasing_command.json").read_text()),
    "input_checksums": {
        "input_vcf": contract["input_vcf_digest"],
        "input_vcf_index": contract["input_vcf_index_digest"],
        "role_aggregate_xam": contract["role_aggregate_xam_digest"],
        "role_aggregate_xam_index": contract["role_aggregate_xam_index_digest"],
        "reference": contract["reference_digest"],
        "phasing_config": contract["phasing_config_digest"],
        "phasing_options": contract["phasing_options_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"] or None,
}, indent=2, sort_keys=True) + "\\n")

Path("qc_stats.json").write_text(json.dumps({
    "schema": "wf-human-variation.somatic_phasing_qc.v1",
    "analysis_intent_id": contract["analysis_intent_id"],
    "sample_id": contract["sample_id"],
    "sample_role": contract["sample_role"],
    "state": state,
    "heterozygous_site_count": het_count,
}, indent=2, sort_keys=True) + "\\n")

for kind, source in {
    "selected_heterozygous_sites": Path("selected_heterozygous_sites.vcf.gz"),
    "somatic_phased_vcf": Path("somatic_phased.vcf.gz"),
    "somatic_phased_vcf_index": Path("somatic_phased.vcf.gz.tbi"),
    "somatic_phasing_manifest": Path("somatic_phasing_manifest.json"),
    "somatic_phasing_command_json": Path("somatic_phasing_command.json"),
    "somatic_phasing_state": Path("somatic_phasing_state.json"),
    "somatic_provenance": Path("somatic_provenance.json"),
    "qc_stats": Path("qc_stats.json"),
}.items():
    if source.exists():
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
        "sample_id": contract["sample_id"],
        "sample_role": contract["sample_role"],
        "state": state,
    },
}
tmp_marker = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp_marker.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp_marker.replace(marker_path)
PY
    """
}

process runBoundedSomaticHaplotaggingTask {
    label "somatic_phasing"
    tag "${entry.analysis_intent_id}:${entry.sample_role}:${entry.sample_id}:${entry.task_key}"

    cpus 2
    memory { 4.GB * task.attempt }
    maxRetries 1
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }

    input:
        val entry
        val contract_json
        path somatic_phased_vcf
        path somatic_phased_vcf_index
        path role_aggregate_xam
        path role_aggregate_xam_index
        path reference
        path reference_index

    output:
        path "somatic_haplotagged.xam", emit: somatic_haplotagged_xam
        path "somatic_haplotagged.xam.xai", emit: somatic_haplotagged_xam_index
        path "somatic_haplotagged_contig_manifest.json", emit: somatic_haplotagged_contig_manifest
        path "somatic_haplotagging_manifest.json", emit: somatic_haplotagging_manifest
        path "somatic_haplotagging_command.json", emit: somatic_haplotagging_command_json
        path "somatic_haplotagging_state.json", emit: somatic_haplotagging_state
        path "somatic_provenance.json", emit: somatic_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-somatic-haplotagging-contract.json <<'JSON'
${contract_json}
JSON

    cp "${somatic_phased_vcf}" somatic_phased.vcf.gz
    cp "${somatic_phased_vcf_index}" somatic_phased.vcf.gz.tbi
    export ROLE_XAM="${role_aggregate_xam}"
    export ROLE_XAM_INDEX="${role_aggregate_xam_index}"
    export REFERENCE_FASTA="${reference}"
    python3 - <<'PY'
import datetime
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


def run_command(cmd, commands):
    resolved = cmd if isinstance(cmd, list) else ["bash", "-o", "pipefail", "-c", cmd]
    commands.append(resolved)
    return subprocess.run(resolved, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def copy_output(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


contract = json.loads(Path("bounded-somatic-haplotagging-contract.json").read_text())
options = contract["somatic_haplotagging_options"]
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
commands = []
state = "completed"
failure = None
output_format = options["output_format"]
out_xam = Path(f"somatic_haplotagged.{output_format}")
out_index = Path(f"{out_xam}.bai" if output_format == "bam" else f"{out_xam}.crai")

whatshap_version = "unknown"
samtools_version = "unknown"
result = run_command(["whatshap", "--version"], commands)
if result.returncode == 0 and result.stdout.strip():
    whatshap_version = result.stdout.strip().splitlines()[0]
result = run_command(["samtools", "--version"], commands)
if result.returncode == 0 and result.stdout.strip():
    samtools_version = result.stdout.strip().splitlines()[0]

if not options["enabled"]:
    state = "skipped_disabled"
    shutil.copy2(os.environ["ROLE_XAM"], out_xam)
    shutil.copy2(os.environ["ROLE_XAM_INDEX"], out_index)
else:
    samtools_format = "BAM" if output_format == "bam" else "CRAM"
    regions = ",".join(options["contigs"])
    pipe_cmd = (
        "whatshap haplotag --reference {ref} --regions {regions} "
        "--ignore-read-groups somatic_phased.vcf.gz {xam} | "
        "samtools view --no-PG -@ 1 --reference {ref} -O {fmt} "
        "-o {out}##idx##{idx} --write-index -"
    ).format(
        ref=os.environ["REFERENCE_FASTA"],
        regions=regions,
        xam=os.environ["ROLE_XAM"],
        fmt=samtools_format,
        out=out_xam,
        idx=out_index,
    )
    result = run_command(pipe_cmd, commands)
    if result.returncode != 0:
        state = "failed"
        failure = {"stage": "whatshap_haplotag", "exit_code": result.returncode, "stderr": result.stderr}

Path("somatic_haplotagging_command.json").write_text(json.dumps({
    "schema": "wf-human-variation.somatic_haplotagging_command.v1",
    "task_key": contract["task_key"],
    "tool": "whatshap",
    "structured_options": options,
    "commands": commands,
}, indent=2, sort_keys=True) + "\\n")

contig_manifest = {
    "schema": "wf-human-variation.somatic_haplotagged_contig_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "sample_id": contract["sample_id"],
    "sample_role": contract["sample_role"],
    "reference_id": contract["reference_id"],
    "state": state,
    "contigs": options["contigs"],
    "final_alignment": {"xam": str(output_paths["somatic_haplotagged_xam"]), "index": str(output_paths["somatic_haplotagged_xam_index"]), "format": output_format},
}
Path("somatic_haplotagged_contig_manifest.json").write_text(json.dumps(contig_manifest, indent=2, sort_keys=True) + "\\n")

Path("somatic_haplotagging_state.json").write_text(json.dumps({
    "schema": "wf-human-variation.somatic_haplotagging_state.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "sample_id": contract["sample_id"],
    "sample_role": contract["sample_role"],
    "reference_id": contract["reference_id"],
    "state": state,
    "failure": failure,
    "haplotagging_policy": {"tool": options["tool"], "enabled": options["enabled"], "output_format": output_format},
}, indent=2, sort_keys=True) + "\\n")

Path("somatic_haplotagging_manifest.json").write_text(json.dumps({
    "schema": "wf-human-variation.somatic_haplotagging_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "pair_id": contract["pair_id"] or None,
    "sample_id": contract["sample_id"],
    "sample_role": contract["sample_role"],
    "reference_id": contract["reference_id"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"] or None,
    "state": state,
    "whatshap_version": whatshap_version,
    "samtools_version": samtools_version,
    "haplotagging_config_digest": contract["haplotagging_config_digest"],
    "haplotagging_options_digest": contract["haplotagging_options_digest"],
    "reference_digest": contract["reference_digest"],
    "container_digest": contract["container_digest"],
    "outputs": {key: str(value) for key, value in output_paths.items()},
}, indent=2, sort_keys=True) + "\\n")

Path("somatic_provenance.json").write_text(json.dumps({
    "schema": "wf-human-variation.somatic_provenance.v1",
    "task_family": contract["task_family"],
    "task_stage": "somatic_haplotagging",
    "task_key": contract["task_key"],
    "tool": "whatshap",
    "tool_version": whatshap_version,
    "container_digest": contract["container_digest"],
    "command_arguments": json.loads(Path("somatic_haplotagging_command.json").read_text()),
    "input_checksums": {
        "somatic_phased_vcf": contract["somatic_phased_vcf_digest"],
        "somatic_phased_vcf_index": contract["somatic_phased_vcf_index_digest"],
        "role_aggregate_xam": contract["role_aggregate_xam_digest"],
        "role_aggregate_xam_index": contract["role_aggregate_xam_index_digest"],
        "reference": contract["reference_digest"],
        "haplotagging_config": contract["haplotagging_config_digest"],
        "haplotagging_options": contract["haplotagging_options_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"] or None,
}, indent=2, sort_keys=True) + "\\n")

Path("qc_stats.json").write_text(json.dumps({
    "schema": "wf-human-variation.somatic_haplotagging_qc.v1",
    "analysis_intent_id": contract["analysis_intent_id"],
    "sample_id": contract["sample_id"],
    "sample_role": contract["sample_role"],
    "state": state,
    "output_format": output_format,
}, indent=2, sort_keys=True) + "\\n")

if state != "failed":
    shutil.copy2(out_xam, "somatic_haplotagged.xam")
    shutil.copy2(out_index, "somatic_haplotagged.xam.xai")
    copy_output(out_xam, output_paths["somatic_haplotagged_xam"])
    copy_output(out_index, output_paths["somatic_haplotagged_xam_index"])
for kind, source in {
    "somatic_haplotagged_contig_manifest": Path("somatic_haplotagged_contig_manifest.json"),
    "somatic_haplotagging_manifest": Path("somatic_haplotagging_manifest.json"),
    "somatic_haplotagging_command_json": Path("somatic_haplotagging_command.json"),
    "somatic_haplotagging_state": Path("somatic_haplotagging_state.json"),
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
        "sample_id": contract["sample_id"],
        "sample_role": contract["sample_role"],
        "state": state,
    },
}
tmp_marker = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp_marker.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp_marker.replace(marker_path)
PY
    """
}
