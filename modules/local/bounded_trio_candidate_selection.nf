process runBoundedTrioCandidateSelectionTask {
    label "clair3nova"
    tag "${entry.family_id}:${entry.analysis_intent_id}:${entry.reference_id}:${entry.task_key}"

    cpus 2
    memory 4.GB

    input:
        val entry
        val contract_json
        path proband_snp_vcf
        path proband_snp_vcf_index
        path father_snp_vcf
        path father_snp_vcf_index
        path mother_snp_vcf
        path mother_snp_vcf_index
        path reference
        path reference_index
        path clair3_nova_model

    output:
        path "trio_candidate_beds", emit: trio_candidate_beds
        path "trio_candidate_contigs.txt", emit: trio_candidate_contigs
        path "trio_candidate_command.json", emit: trio_candidate_command_json
        path "trio_candidate_manifest.json", emit: trio_candidate_manifest
        path "family_provenance.json", emit: family_provenance
        path "qc_stats.json", emit: qc_stats

    script:
    """
    set -euo pipefail

    cat > bounded-family-germline-snp-contract.json <<'JSON'
${contract_json}
JSON

    export PROBAND_SNP_VCF="${proband_snp_vcf}"
    export FATHER_SNP_VCF="${father_snp_vcf}"
    export MOTHER_SNP_VCF="${mother_snp_vcf}"
    export REFERENCE_FASTA="${reference}"
    export CLAIR3_NOVA_MODEL="${clair3_nova_model}"
    python3 - <<'PY'
import json
import os
import shlex
from pathlib import Path

contract = json.loads(Path("bounded-family-germline-snp-contract.json").read_text())
options = contract["family_germline_options"]
contigs = [str(contig) for contig in options["candidate_contigs"]]
if not contigs:
    raise ValueError("candidate_contigs must not be empty")
clair3_nova_path = os.environ.get("CLAIR3_NOVA_PATH", "").strip()
if not clair3_nova_path:
    raise EnvironmentError("CLAIR3_NOVA_PATH must be set by the Clair3-Nova container")
clair3_nova_script = str(Path(clair3_nova_path) / "clair3.py")

commands = []
shell_lines = ["mkdir -p trio_candidate_beds"]
for contig in contigs:
    cmd = [
        "pypy",
        clair3_nova_script,
        "SelectCandidates_Trio",
        "--alt_fn_c",
        os.environ["PROBAND_SNP_VCF"],
        "--alt_fn_p1",
        os.environ["FATHER_SNP_VCF"],
        "--alt_fn_p2",
        os.environ["MOTHER_SNP_VCF"],
        "--candidate_bed",
        "trio_candidate_beds",
        "--sampleName",
        "trio",
        "--ref_pct_full",
        str(options["ref_pct_full"]),
        "--var_pct_full",
        str(options["var_pct_full"]),
        "--ref_var_max_ratio",
        str(options["ref_var_max_ratio"]),
        "--ctgName",
        contig,
    ]
    commands.append({"contig": contig, "command": cmd})
    shell_lines.append(" ".join(shlex.quote(part) for part in cmd))

Path("run-trio-candidate-selection.sh").write_text("\\n".join(shell_lines) + "\\n")
Path("trio_candidate_command.json").write_text(json.dumps(commands, indent=2, sort_keys=True) + "\\n")
Path("trio_candidate_contigs.txt").write_text("\\n".join(contigs) + "\\n")
PY

    bash run-trio-candidate-selection.sh

    python3 - <<'PY'
import datetime
import json
import shutil
from pathlib import Path

contract = json.loads(Path("bounded-family-germline-snp-contract.json").read_text())
output_paths = {key: Path(value) for key, value in contract["output_paths"].items()}
commands = json.loads(Path("trio_candidate_command.json").read_text())
contigs = Path("trio_candidate_contigs.txt").read_text().splitlines()

candidate_files = sorted(str(path) for path in Path("trio_candidate_beds").glob("*"))
manifest = {
    "schema": "wf-human-variation.trio_candidate_manifest.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
    "role_sample_ids": {
        "proband": contract["proband_sample_id"],
        "father": contract["father_sample_id"],
        "mother": contract["mother_sample_id"],
    },
    "input_vcf_kind": "snp_vcf",
    "input_vcf_kind_note": "wf-trio used Clair3 pileup VCFs here; this bounded contract is role-keyed so the input kind can be refined without changing family identity.",
    "input_vcfs": {
        "proband": contract["proband_snp_vcf"],
        "father": contract["father_snp_vcf"],
        "mother": contract["mother_snp_vcf"],
    },
    "input_vcf_indexes": {
        "proband": contract["proband_snp_vcf_index"],
        "father": contract["father_snp_vcf_index"],
        "mother": contract["mother_snp_vcf_index"],
    },
    "reference_fasta": contract["reference_fasta"],
    "clair3_nova_model_digest": contract["clair3_nova_model_digest"],
    "family_germline_config_digest": contract["family_germline_config_digest"],
    "container_digest": contract["container_digest"],
    "candidate_contigs": contigs,
    "candidate_file_count": len(candidate_files),
    "outputs": {
        "trio_candidate_manifest": str(output_paths["trio_candidate_manifest"]),
        "trio_candidate_beds": str(output_paths["trio_candidate_beds"]),
        "trio_candidate_contigs": str(output_paths["trio_candidate_contigs"]),
        "trio_candidate_command_json": str(output_paths["trio_candidate_command_json"]),
    },
}
Path("trio_candidate_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\\n")

provenance = {
    "schema": "wf-human-variation.family_provenance.v1",
    "task_family": contract["task_family"],
    "task_key": contract["task_key"],
    "tool": "clair3-nova",
    "container_digest": contract["container_digest"],
    "command_arguments": commands,
    "input_checksums": {
        "proband_snp_vcf": contract["proband_snp_vcf_digest"],
        "proband_snp_vcf_index": contract["proband_snp_vcf_index_digest"],
        "father_snp_vcf": contract["father_snp_vcf_digest"],
        "father_snp_vcf_index": contract["father_snp_vcf_index_digest"],
        "mother_snp_vcf": contract["mother_snp_vcf_digest"],
        "mother_snp_vcf_index": contract["mother_snp_vcf_index_digest"],
        "family_germline_config": contract["family_germline_config_digest"],
    },
    "model_checksums": {
        "clair3_nova_model": contract["clair3_nova_model_digest"],
    },
    "role_snapshot_digest": contract["role_snapshot_digest"],
    "relationship_snapshot_digest": contract["relationship_snapshot_digest"],
}
Path("family_provenance.json").write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\\n")

qc = {
    "schema": "wf-human-variation.trio_candidate_qc.v1",
    "family_id": contract["family_id"],
    "analysis_intent_id": contract["analysis_intent_id"],
    "reference_id": contract["reference_id"],
    "task_key": contract["task_key"],
    "contig_count": len(contigs),
    "candidate_file_count": len(candidate_files),
}
Path("qc_stats.json").write_text(json.dumps(qc, indent=2, sort_keys=True) + "\\n")

copies = {
    "trio_candidate_manifest": Path("trio_candidate_manifest.json"),
    "trio_candidate_beds": Path("trio_candidate_beds"),
    "trio_candidate_contigs": Path("trio_candidate_contigs.txt"),
    "trio_candidate_command_json": Path("trio_candidate_command.json"),
    "family_provenance": Path("family_provenance.json"),
    "qc_stats": Path("qc_stats.json"),
}
for kind, source in copies.items():
    target = output_paths[kind]
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.is_dir():
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(source, target)
    else:
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
        "family_id": contract["family_id"],
        "analysis_intent_id": contract["analysis_intent_id"],
        "reference_id": contract["reference_id"],
        "contig_count": len(contigs),
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
