process runBoundedFamilyHaplotaggingTask {
    label "wftrio"
    tag "${entry.family_id}:${entry.analysis_intent_id}:${entry.reference_id}:${entry.task_key}"

    cpus 2
    memory { 4.GB * task.attempt }
    errorStrategy { task.exitStatus in [137, 140] ? 'retry' : 'finish' }
    maxRetries 2

    input:
        val entry
        val contract_json
        path pedigree_filtered_vcf
        path pedigree_filtered_vcf_index
        path proband_xam
        path proband_xam_index
        path father_xam
        path father_xam_index
        path mother_xam
        path mother_xam_index
        path reference
        path reference_index

    output:
        path "family_haplotagged_alignments", emit: family_haplotagged_alignments
        path "family_haplotagged_contig_manifest.json", emit: family_haplotagged_contig_manifest
        path "family_haplotagging_manifest.json", emit: family_haplotagging_manifest
        path "family_haplotagging_state.json", emit: family_haplotagging_state
        path "family_provenance.json", emit: family_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-family-haplotagging-contract.json <<'JSON'
${contract_json}
JSON

    cp "${pedigree_filtered_vcf}" pedigree_filtered.vcf.gz
    cp "${pedigree_filtered_vcf_index}" pedigree_filtered.vcf.gz.tbi

    export PROBAND_XAM="${proband_xam}"
    export PROBAND_XAM_INDEX="${proband_xam_index}"
    export FATHER_XAM="${father_xam}"
    export FATHER_XAM_INDEX="${father_xam_index}"
    export MOTHER_XAM="${mother_xam}"
    export MOTHER_XAM_INDEX="${mother_xam_index}"
    export REFERENCE_FASTA="${reference}"
    python3 - <<'PY'
import datetime
import json
import os
import re
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
    if source.is_dir():
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(source, target)
    else:
        shutil.copy2(source, target)


def safe_name(value):
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", value).strip("._") or "sample"


def stage_alignment(role, xam_env, index_env):
    source = Path(os.environ[xam_env])
    suffix = source.suffix.lower()
    if suffix not in {".bam", ".cram"}:
        raise ValueError(f"{role} alignment must be BAM or CRAM, received {source}")
    staged = Path(f"{role}.input{suffix}")
    shutil.copy2(source, staged)
    if suffix == ".bam":
        staged_index = Path(f"{staged}.bai")
    else:
        staged_index = Path(f"{staged}.crai")
    shutil.copy2(Path(os.environ[index_env]), staged_index)
    return staged, staged_index


contract = json.loads(Path("bounded-family-haplotagging-contract.json").read_text())
options = contract["family_haplotagging_options"]
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
role_samples = {
    "proband": contract["proband_sample_id"],
    "father": contract["father_sample_id"],
    "mother": contract["mother_sample_id"],
}
role_inputs = {
    "proband": stage_alignment("proband", "PROBAND_XAM", "PROBAND_XAM_INDEX"),
    "father": stage_alignment("father", "FATHER_XAM", "FATHER_XAM_INDEX"),
    "mother": stage_alignment("mother", "MOTHER_XAM", "MOTHER_XAM_INDEX"),
}

commands = []
contigs = [str(contig) for contig in options["contigs"]]
output_format = options["output_format"]
alignments_dir = Path("family_haplotagged_alignments")
contig_dir = alignments_dir / "contigs"
final_dir = alignments_dir / "final"
for directory in (contig_dir, final_dir):
    directory.mkdir(parents=True, exist_ok=True)

state = "completed"
failure = None
contig_manifest = []
final_outputs = {}

whatshap_version = "unknown"
samtools_version = "unknown"
version_result = run_command(["whatshap", "--version"], commands)
if version_result.returncode == 0 and version_result.stdout.strip():
    whatshap_version = version_result.stdout.strip().splitlines()[0]
version_result = run_command(["samtools", "--version"], commands)
if version_result.returncode == 0 and version_result.stdout.strip():
    samtools_version = version_result.stdout.strip().splitlines()[0]

if not options["enabled"]:
    state = "skipped_disabled"

if state == "completed":
    for role, sample_id in role_samples.items():
        staged_xam, _staged_index = role_inputs[role]
        sample_slug = safe_name(sample_id)
        role_contig_paths = []
        for contig in contigs:
            contig_slug = safe_name(contig)
            filtered_vcf = contig_dir / f"{role}.{sample_slug}.{contig_slug}.vcf.gz"
            output_ext = output_format
            contig_xam = contig_dir / f"{role}.{sample_slug}.{contig_slug}.haplotagged.{output_ext}"
            contig_index = Path(f"{contig_xam}.bai" if output_format == "bam" else f"{contig_xam}.crai")

            result = run_command([
                "bcftools",
                "view",
                "-a",
                "-s",
                sample_id,
                "--regions",
                contig,
                "-O",
                "z",
                "-o",
                str(filtered_vcf),
                "pedigree_filtered.vcf.gz",
            ], commands)
            if result.returncode != 0:
                state = "failed"
                failure = {"stage": "filter_phased_vcf", "role": role, "contig": contig, "exit_code": result.returncode, "stderr": result.stderr}
                break

            result = run_command(["tabix", "-p", "vcf", str(filtered_vcf)], commands)
            if result.returncode != 0:
                state = "failed"
                failure = {"stage": "index_filtered_phased_vcf", "role": role, "contig": contig, "exit_code": result.returncode, "stderr": result.stderr}
                break

            samtools_format = "BAM" if output_format == "bam" else "CRAM"
            pipe_cmd = (
                "whatshap haplotag --reference {ref} --regions {contig} "
                "--ignore-read-groups {vcf} {xam} | "
                "samtools view --no-PG -@ 1 --reference {ref} -O {fmt} "
                "-o {out}##idx##{idx} --write-index -"
            ).format(
                ref=os.environ["REFERENCE_FASTA"],
                contig=contig,
                vcf=filtered_vcf,
                xam=staged_xam,
                fmt=samtools_format,
                out=contig_xam,
                idx=contig_index,
            )
            result = run_command(pipe_cmd, commands)
            if result.returncode != 0:
                state = "failed"
                failure = {"stage": "whatshap_haplotag", "role": role, "contig": contig, "exit_code": result.returncode, "stderr": result.stderr}
                break

            role_contig_paths.append(contig_xam)
            contig_manifest.append({
                "role": role,
                "sample_id": sample_id,
                "contig": contig,
                "xam": str(contig_xam),
                "index": str(contig_index),
                "format": output_format,
            })

        if state != "completed":
            break

        fofn = Path(f"{role}.{sample_slug}.haplotagged.fofn")
        fofn.write_text("\\n".join(str(path) for path in role_contig_paths) + "\\n")
        final_xam = final_dir / f"{role}.{sample_slug}.haplotagged.{output_format}"
        final_index = Path(f"{final_xam}.bai" if output_format == "bam" else f"{final_xam}.crai")
        if output_format == "bam":
            result = run_command(["samtools", "cat", "-b", str(fofn), "--no-PG", "-o", str(final_xam)], commands)
            if result.returncode == 0:
                result = run_command(["samtools", "index", "-b", str(final_xam)], commands)
        else:
            merge_cmd = (
                "samtools cat -b {fofn} --no-PG -o - | "
                "samtools view --no-PG --reference {ref} -O CRAM "
                "--write-index -o {out}##idx##{idx} -"
            ).format(fofn=fofn, ref=os.environ["REFERENCE_FASTA"], out=final_xam, idx=final_index)
            result = run_command(merge_cmd, commands)
        if result.returncode != 0:
            state = "failed"
            failure = {"stage": "merge_haplotagged_contigs", "role": role, "exit_code": result.returncode, "stderr": result.stderr}
            break
        final_outputs[role] = {
            "sample_id": sample_id,
            "xam": str(final_xam),
            "index": str(final_index),
            "format": output_format,
        }

Path("family_haplotagged_contig_manifest.json").write_text(json.dumps({
    "schema": "wf-human-variation.family_haplotagged_contig_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "state": state,
    "contigs": contig_manifest,
    "final_alignments": final_outputs,
}, indent=2, sort_keys=True) + "\\n")

Path("family_haplotagging_state.json").write_text(json.dumps({
    "schema": "wf-human-variation.family_haplotagging_state.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "state": state,
    "failure": failure,
    "contigs": contigs,
    "output_format": output_format,
}, indent=2, sort_keys=True) + "\\n")

Path("family_haplotagging_manifest.json").write_text(json.dumps({
    "schema": "wf-human-variation.family_haplotagging_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
    "role_sample_ids": role_samples,
    "state": state,
    "whatshap_version": whatshap_version,
    "samtools_version": samtools_version,
    "whatshap_config_digest": contract["whatshap_config_digest"],
    "reference_digest": contract["reference_digest"],
    "container_digest": contract["container_digest"],
    "outputs": {
        "family_haplotagged_alignments": str(output_paths["family_haplotagged_alignments"]),
        "family_haplotagged_contig_manifest": str(output_paths["family_haplotagged_contig_manifest"]),
        "family_haplotagging_manifest": str(output_paths["family_haplotagging_manifest"]),
        "family_haplotagging_state": str(output_paths["family_haplotagging_state"]),
    },
}, indent=2, sort_keys=True) + "\\n")

Path("family_provenance.json").write_text(json.dumps({
    "schema": "wf-human-variation.family_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "tool": "whatshap",
    "tool_version": whatshap_version,
    "container_digest": contract["container_digest"],
    "command_arguments": commands,
    "input_checksums": {
        "pedigree_filtered_vcf": contract["pedigree_filtered_vcf_digest"],
        "pedigree_filtered_vcf_index": contract["pedigree_filtered_vcf_index_digest"],
        "proband_xam": contract["proband_xam_digest"],
        "proband_xam_index": contract["proband_xam_index_digest"],
        "father_xam": contract["father_xam_digest"],
        "father_xam_index": contract["father_xam_index_digest"],
        "mother_xam": contract["mother_xam_digest"],
        "mother_xam_index": contract["mother_xam_index_digest"],
        "reference": contract["reference_digest"],
        "whatshap_config": contract["whatshap_config_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
}, indent=2, sort_keys=True) + "\\n")

Path("qc_stats.json").write_text(json.dumps({
    "schema": "wf-human-variation.family_haplotagging_qc.v1",
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "task_key": contract["task_key"],
    "state": state,
    "contig_count": len(contigs),
    "haplotagged_contig_count": len(contig_manifest),
    "haplotagged_sample_count": len(final_outputs),
}, indent=2, sort_keys=True) + "\\n")

if state == "failed":
    for kind, source in {
        "family_haplotagged_contig_manifest": Path("family_haplotagged_contig_manifest.json"),
        "family_haplotagging_manifest": Path("family_haplotagging_manifest.json"),
        "family_haplotagging_state": Path("family_haplotagging_state.json"),
        "family_provenance": Path("family_provenance.json"),
        "qc_stats": Path("qc_stats.json"),
    }.items():
        copy_output(source, output_paths[kind])
    copy_output(alignments_dir, output_paths["family_haplotagged_alignments"])
    sys.exit(1)

for kind, source in {
    "family_haplotagged_alignments": alignments_dir,
    "family_haplotagged_contig_manifest": Path("family_haplotagged_contig_manifest.json"),
    "family_haplotagging_manifest": Path("family_haplotagging_manifest.json"),
    "family_haplotagging_state": Path("family_haplotagging_state.json"),
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
        "reference_id": contract["reference_id"],
        "state": state,
        "haplotagged_sample_count": len(final_outputs),
    },
}
tmp_marker = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp_marker.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp_marker.replace(marker_path)
PY
    """
}
