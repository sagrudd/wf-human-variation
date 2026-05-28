"""Performance and barrier regression gates for phase 4 paired entries."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

PAIRED_ENTRY_MODULES = [
    "modules/local/bounded_somatic_paired_snv.nf",
    "modules/local/bounded_somatic_paired_sv.nf",
    "modules/local/bounded_somatic_qc.nf",
    "modules/local/bounded_somatic_differential_methylation.nf",
]

PAIRED_ENTRY_WORKFLOWS = [
    "somatic_paired_snv_candidate",
    "somatic_paired_snv_pileup",
    "somatic_paired_snv_full_alignment",
    "somatic_paired_snv_merge",
    "somatic_paired_snv_haplotype_filter",
    "somatic_qc",
    "somatic_paired_sv",
    "somatic_differential_methylation",
]

PAIRED_ENTRY_RUNNERS = {
    "somatic_paired_snv_candidate": "runBoundedSomaticPairedSnvCandidateTask",
    "somatic_paired_snv_pileup": "runBoundedSomaticPairedSnvPileupTask",
    "somatic_paired_snv_full_alignment": "runBoundedSomaticPairedSnvFullAlignmentTask",
    "somatic_paired_snv_merge": "runBoundedSomaticPairedSnvMergeTask",
    "somatic_paired_snv_haplotype_filter": "runBoundedSomaticPairedSnvHaplotypeFilterTask",
    "somatic_qc": "runBoundedSomaticQcTask",
    "somatic_paired_sv": "runBoundedSomaticPairedSvTask",
    "somatic_differential_methylation": "runBoundedSomaticDifferentialMethylationTask",
}

PAIRED_ENTRY_HELPERS = {
    "boundedSomaticPairedSnvCandidateEntryParams": [
        "analysis_intent_id",
        "pair_id",
        "role_snapshot_digest",
        "relationship_snapshot_digest",
        "contig",
    ],
    "boundedSomaticPairedSnvPileupEntryParams": [
        "analysis_intent_id",
        "pair_id",
        "role_snapshot_digest",
        "relationship_snapshot_digest",
        "contig",
    ],
    "boundedSomaticPairedSnvFullAlignmentEntryParams": [
        "analysis_intent_id",
        "pair_id",
        "role_snapshot_digest",
        "relationship_snapshot_digest",
        "contig",
    ],
    "boundedSomaticPairedSnvMergeEntryParams": [
        "analysis_intent_id",
        "pair_id",
        "role_snapshot_digest",
        "relationship_snapshot_digest",
    ],
    "boundedSomaticPairedSnvHaplotypeFilterEntryParams": [
        "analysis_intent_id",
        "pair_id",
        "role_snapshot_digest",
        "relationship_snapshot_digest",
        "contig",
    ],
    "boundedSomaticQcEntryParams": [
        "analysis_intent_id",
        "pair_id",
        "role_snapshot_digest",
        "relationship_snapshot_digest",
    ],
    "boundedSomaticPairedSvEntryParams": [
        "analysis_intent_id",
        "pair_id",
        "role_snapshot_digest",
        "relationship_snapshot_digest",
    ],
    "boundedSomaticDifferentialMethylationEntryParams": [
        "analysis_intent_id",
        "pair_id",
        "role_snapshot_digest",
        "relationship_snapshot_digest",
        "modification_code",
    ],
}


def read(path: str) -> str:
    return (REPO_ROOT / path).read_text()


def workflow_block(name: str) -> str:
    text = read("main.nf")
    match = re.search(rf"(?ms)^workflow {re.escape(name)} \{{.*?(?=^workflow |\Z)", text)
    if not match:
        raise AssertionError(f"workflow {name} not found")
    return match.group(0)


def helper_block(name: str) -> str:
    text = read("lib/bounded_entry.nf")
    match = re.search(rf"(?ms)^def {re.escape(name)}\(params\) \{{.*?(?=^def |\Z)", text)
    if not match:
        raise AssertionError(f"helper {name} not found")
    return match.group(0)


class Phase4PairedPerformanceGateTest(unittest.TestCase):
    def test_paired_entries_do_not_use_global_channel_barriers(self):
        forbidden = [
            r"(?<![A-Za-z0-9_])collect\s*\(",
            r"(?<![A-Za-z0-9_])combine\s*\(",
            r"(?<![A-Za-z0-9_])first\s*\(",
            r"(?<![A-Za-z0-9_])groupTuple\s*\(",
        ]
        surfaces = {
            **{path: read(path) for path in PAIRED_ENTRY_MODULES},
            **{f"main.nf::{name}": workflow_block(name) for name in PAIRED_ENTRY_WORKFLOWS},
        }

        for surface_name, surface in surfaces.items():
            for pattern in forbidden:
                with self.subTest(surface=surface_name, pattern=pattern):
                    self.assertIsNone(re.search(pattern, surface))

    def test_paired_entries_do_not_reintroduce_report_generation(self):
        forbidden_patterns = [
            r"\bmakeReport\s*\(",
            r"\bworkflow-glue\s+report_",
            r"\breport_(?:snp|sv|cnv|str|al|mod)\b",
            r"\boutput_report\b",
            r"\breport_html\b",
            r"\btext/html\b",
            r"\.html\b",
            r"<html\b",
            r"\bpublishDir\b",
        ]
        surfaces = {
            **{path: read(path) for path in PAIRED_ENTRY_MODULES},
            **{f"main.nf::{name}": workflow_block(name) for name in PAIRED_ENTRY_WORKFLOWS},
        }

        for surface_name, surface in surfaces.items():
            for pattern in forbidden_patterns:
                with self.subTest(surface=surface_name, pattern=pattern):
                    self.assertIsNone(re.search(pattern, surface, flags=re.IGNORECASE))

    def test_paired_entries_do_not_consume_hidden_optional_file_sentinels(self):
        forbidden = ["OPTIONAL_FILE", "__wf_human_variation_absent_input__", "data/OPTIONAL_FILE"]
        surfaces = {
            **{path: read(path) for path in PAIRED_ENTRY_MODULES},
            **{f"main.nf::{name}": workflow_block(name) for name in PAIRED_ENTRY_WORKFLOWS},
        }

        for surface_name, surface in surfaces.items():
            for token in forbidden:
                with self.subTest(surface=surface_name, token=token):
                    self.assertNotIn(token, surface)

    def test_paired_entries_reject_free_form_tool_argument_pass_throughs(self):
        forbidden_patterns = [
            r"\bparams\.[A-Za-z0-9_]*_args\b",
            r"\b(?:clairs|clairs_to|severus|modkit|dss|phasing|longphase|whatshap)_args\b",
            r"\btask\.ext\.args\b",
            r"\bext\.args\b",
            r"\bargs\s*=\s*params\b",
        ]
        surfaces = {
            **{path: read(path) for path in PAIRED_ENTRY_MODULES},
            **{f"main.nf::{name}": workflow_block(name) for name in PAIRED_ENTRY_WORKFLOWS},
        }

        for surface_name, surface in surfaces.items():
            for pattern in forbidden_patterns:
                with self.subTest(surface=surface_name, pattern=pattern):
                    self.assertIsNone(re.search(pattern, surface))

    def test_paired_entries_do_not_mutate_global_workflow_params(self):
        mutation = re.compile(r"params\.wf(?:\[[^\]]+\]|\.[A-Za-z0-9_]+)\s*=")
        surfaces = {
            **{path: read(path) for path in PAIRED_ENTRY_MODULES},
            **{f"main.nf::{name}": workflow_block(name) for name in PAIRED_ENTRY_WORKFLOWS},
        }

        for surface_name, surface in surfaces.items():
            with self.subTest(surface=surface_name):
                self.assertIsNone(mutation.search(surface))

    def test_paired_entry_workflows_launch_only_their_bounded_runner(self):
        forbidden = [
            "WorkflowMain",
            "combine_metrics_json",
            "publish_artifact",
            "makeReport",
            "workflow-glue report_",
            "output_report",
            "report_html",
        ]
        for workflow, expected_runner in PAIRED_ENTRY_RUNNERS.items():
            block = workflow_block(workflow)
            runners = re.findall(r"\brunBounded[A-Za-z0-9]+Task\b", block)
            with self.subTest(workflow=workflow, check="runner"):
                self.assertEqual(runners, [expected_runner])
            for token in forbidden:
                with self.subTest(workflow=workflow, token=token):
                    self.assertNotIn(token, block)

    def test_paired_entry_helpers_require_controller_owned_key_fields(self):
        for helper, scoped_fields in PAIRED_ENTRY_HELPERS.items():
            block = helper_block(helper)
            with self.subTest(helper=helper, field="task_key"):
                self.assertIn('_requiredBoundedParam(params, "task_key")', block)
            with self.subTest(helper=helper, field="completion_marker_path"):
                self.assertIn('_requiredBoundedParam(params, "completion_marker_path")', block)
            for field in scoped_fields:
                with self.subTest(helper=helper, field=field):
                    self.assertIn(f'_requiredBoundedParam(params, "{field}")', block)

    def test_paired_barrier_contract_is_documented(self):
        docs = read("docs/keyed-joins.rst")
        self.assertIn("Phase 4 Paired Barrier Gate", docs)
        self.assertIn("paired tumour-normal bounded entries have no accepted channel-barrier debt", docs)
        for entry in PAIRED_ENTRY_WORKFLOWS:
            with self.subTest(entry=entry):
                self.assertIn(f"``{entry}``", docs)
        for phrase in [
            "analysis_intent_id",
            "pair_id",
            "role_snapshot_digest",
            "relationship_snapshot_digest",
            "task_key",
            "report-generation",
            "free-form shell option",
            "OPTIONAL_FILE",
        ]:
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, docs)


if __name__ == "__main__":
    unittest.main()
