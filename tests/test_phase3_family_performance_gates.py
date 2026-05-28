"""Performance and barrier regression gates for phase 3 family entries."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

FAMILY_ENTRY_MODULES = [
    "modules/local/bounded_trio_candidate_selection.nf",
    "modules/local/bounded_trio_denovo_calling.nf",
    "modules/local/bounded_trio_merge_sort.nf",
    "modules/local/bounded_family_joint_genotyping.nf",
    "modules/local/bounded_family_pedigree_phasing.nf",
    "modules/local/bounded_family_haplotagging.nf",
    "modules/local/bounded_family_sv_calling.nf",
    "modules/local/bounded_family_sv_merging.nf",
    "modules/local/bounded_family_mendelian_assessment.nf",
]

FAMILY_ENTRY_WORKFLOWS = [
    "family_germline_snp",
    "family_germline_snp_denovo",
    "family_germline_snp_merge",
    "family_joint_genotyping",
    "family_pedigree_phasing",
    "family_haplotagging",
    "family_sv_calling",
    "family_sv_merging",
    "family_mendelian_assessment",
]

FAMILY_ENTRY_RUNNERS = {
    "family_germline_snp": "runBoundedTrioCandidateSelectionTask",
    "family_germline_snp_denovo": "runBoundedTrioDenovoCallingTask",
    "family_germline_snp_merge": "runBoundedTrioMergeSortTask",
    "family_joint_genotyping": "runBoundedFamilyJointGenotypingTask",
    "family_pedigree_phasing": "runBoundedFamilyPedigreePhasingTask",
    "family_haplotagging": "runBoundedFamilyHaplotaggingTask",
    "family_sv_calling": "runBoundedFamilySvCallingTask",
    "family_sv_merging": "runBoundedFamilySvMergingTask",
    "family_mendelian_assessment": "runBoundedFamilyMendelianAssessmentTask",
}

FAMILY_ENTRY_HELPERS = {
    "boundedFamilyGermlineSnpEntryParams": ["family_id", "analysis_intent_id", "role_snapshot_digest"],
    "boundedFamilyGermlineSnpDenovoEntryParams": ["family_id", "analysis_intent_id", "role_snapshot_digest"],
    "boundedFamilyGermlineSnpMergeEntryParams": ["family_id", "analysis_intent_id", "role_snapshot_digest", "role", "sample_id"],
    "boundedFamilyJointGenotypingEntryParams": ["family_id", "analysis_intent_id", "role_snapshot_digest"],
    "boundedFamilyPedigreePhasingEntryParams": ["family_id", "analysis_intent_id", "role_snapshot_digest"],
    "boundedFamilyHaplotaggingEntryParams": ["family_id", "analysis_intent_id", "role_snapshot_digest"],
    "boundedFamilySvCallingEntryParams": ["family_id", "analysis_intent_id", "role_snapshot_digest", "role", "sample_id"],
    "boundedFamilySvMergingEntryParams": ["family_id", "analysis_intent_id", "role_snapshot_digest"],
    "boundedFamilyMendelianAssessmentEntryParams": ["family_id", "analysis_intent_id", "role_snapshot_digest"],
}


def read(path: str) -> str:
    return (REPO_ROOT / path).read_text()


def family_workflow_block(name: str) -> str:
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


class Phase3FamilyPerformanceGateTest(unittest.TestCase):
    def test_family_entries_do_not_use_global_channel_barriers(self):
        forbidden = [
            r"(?<![A-Za-z0-9_])collect\s*\(",
            r"(?<![A-Za-z0-9_])combine\s*\(",
            r"(?<![A-Za-z0-9_])first\s*\(",
            r"(?<![A-Za-z0-9_])groupTuple\s*\(",
        ]
        surfaces = {
            **{path: read(path) for path in FAMILY_ENTRY_MODULES},
            **{f"main.nf::{name}": family_workflow_block(name) for name in FAMILY_ENTRY_WORKFLOWS},
        }

        for surface_name, surface in surfaces.items():
            for pattern in forbidden:
                with self.subTest(surface=surface_name, pattern=pattern):
                    self.assertIsNone(re.search(pattern, surface))

    def test_family_entries_do_not_reintroduce_html_report_commands(self):
        forbidden_patterns = [
            r"\bmakeReport\s*\(",
            r"\bworkflow-glue\s+report_",
            r"\breport_(?:snp|sv|cnv|str|al)\b",
            r"\boutput_report\b",
            r"\breport_html\b",
            r"\btext/html\b",
            r"\.html\b",
            r"<html\b",
        ]
        surfaces = {path: read(path) for path in FAMILY_ENTRY_MODULES}

        for surface_name, surface in surfaces.items():
            for pattern in forbidden_patterns:
                with self.subTest(surface=surface_name, pattern=pattern):
                    self.assertIsNone(re.search(pattern, surface, flags=re.IGNORECASE))

    def test_family_entries_do_not_consume_legacy_optional_file_sentinel(self):
        forbidden = ["OPTIONAL_FILE", "__wf_human_variation_absent_input__", "data/OPTIONAL_FILE"]
        surfaces = {
            **{path: read(path) for path in FAMILY_ENTRY_MODULES},
            **{f"main.nf::{name}": family_workflow_block(name) for name in FAMILY_ENTRY_WORKFLOWS},
        }

        for surface_name, surface in surfaces.items():
            for token in forbidden:
                with self.subTest(surface=surface_name, token=token):
                    self.assertNotIn(token, surface)

    def test_optional_boundary_channels_are_only_explicit_family_subset_boundaries(self):
        expected_counts = {
            "family_sv_merging": 3,
            "family_mendelian_assessment": 4,
        }
        for workflow in FAMILY_ENTRY_WORKFLOWS:
            block = family_workflow_block(workflow)
            expected = expected_counts.get(workflow, 0)
            with self.subTest(workflow=workflow):
                self.assertEqual(block.count("optionalBoundaryChannel()"), expected)

    def test_family_entry_workflows_launch_only_their_bounded_runner(self):
        forbidden = [
            "WorkflowMain",
            "combine_metrics_json",
            "publish_artifact",
            "makeReport",
            "workflow-glue report_",
            "output_report",
            "report_html",
        ]
        for workflow, expected_runner in FAMILY_ENTRY_RUNNERS.items():
            block = family_workflow_block(workflow)
            runners = re.findall(r"\brunBounded[A-Za-z0-9]+Task\b", block)
            with self.subTest(workflow=workflow, check="runner"):
                self.assertEqual(runners, [expected_runner])
            for token in forbidden:
                with self.subTest(workflow=workflow, token=token):
                    self.assertNotIn(token, block)

    def test_family_entry_helpers_require_controller_owned_key_fields(self):
        for helper, scoped_fields in FAMILY_ENTRY_HELPERS.items():
            block = helper_block(helper)
            with self.subTest(helper=helper, field="task_key"):
                self.assertIn('_requiredBoundedParam(params, "task_key")', block)
            with self.subTest(helper=helper, field="completion_marker_path"):
                self.assertIn('_requiredBoundedParam(params, "completion_marker_path")', block)
            for field in scoped_fields:
                with self.subTest(helper=helper, field=field):
                    self.assertIn(f'_requiredBoundedParam(params, "{field}")', block)

    def test_family_barrier_compatibility_debt_is_documented(self):
        docs = read("docs/keyed-joins.rst")
        self.assertIn("Phase 3 Family Barrier Gate", docs)
        self.assertIn("The phase-3 family bounded entries have no accepted channel-barrier debt.", docs)
        for entry in FAMILY_ENTRY_WORKFLOWS:
            with self.subTest(entry=entry):
                self.assertIn(f"``{entry}``", docs)
        for phrase in [
            "family_id",
            "analysis_intent_id",
            "role",
            "sample_id",
            "task_key",
            "OPTIONAL_FILE",
            "HTML report",
        ]:
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, docs)


if __name__ == "__main__":
    unittest.main()
