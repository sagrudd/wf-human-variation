"""Release acceptance gates for phase 4 tasks 20 and 40."""

from __future__ import annotations

import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (REPO_ROOT / path).read_text()


class Phase4ReleaseAcceptanceTest(unittest.TestCase):
    def test_phase4_acceptance_page_is_in_sphinx_canon(self):
        index = read("docs/index.rst")
        acceptance = read("docs/phase4-acceptance.rst")

        self.assertIn("phase4-acceptance", index)
        self.assertIn("Phase 4 Somatic And Paired Acceptance", acceptance)
        self.assertIn("Phase 4 tasks 1-40 are implementation-complete for local contract review only", acceptance)
        self.assertIn("Phase 4 tasks 1-20 are implementation-complete for local contract review only", acceptance)
        self.assertIn("not release-accepted for customer or production use", acceptance)
        self.assertIn("committed fork revision", acceptance)
        self.assertIn("missing parent submodule pin", acceptance)
        self.assertIn("Paired tumour-normal task families remain", acceptance)
        self.assertIn("Phase 4 Somatic Foundation Acceptance", acceptance)

    def test_required_somatic_foundation_contracts_are_named(self):
        acceptance = read("docs/phase4-acceptance.rst")
        for task_family in [
            "somatic_qc",
            "somatic_tumour_only_snv",
            "somatic_tumour_only_sv",
            "somatic_methylation_aggregation",
            "somatic_annotation",
            "somatic_export",
        ]:
            with self.subTest(task_family=task_family):
                self.assertIn(f"``{task_family}``", acceptance)
        for entry in [
            "``-entry somatic_tumour_only_snv``",
            "``-entry somatic_tumour_only_sv``",
            "``-entry somatic_methylation_aggregation``",
            "``-entry somatic_annotation``",
        ]:
            with self.subTest(entry=entry):
                self.assertIn(entry, acceptance)

    def test_minimum_contract_and_synthetic_gates_are_documented(self):
        acceptance = read("docs/phase4-acceptance.rst")
        for token in [
            "tests/test_bounded_entry_contract.py",
            "tests/test_phase2_synthetic_contracts.py",
            "tests/test_phase4_paired_performance_gates.py",
            "somatic analysis intents",
            "sample roles",
            "somatic manifest projection",
            "tumour-only readiness",
            "paired identity",
            "dynamic paired arrival",
            "duplicate aggregate artefacts",
            "imported normal/control VCF state",
            "shared callable regions",
            "missing PON fallback",
            "tumour_rejected_low_coverage",
            "synthetic paired integration",
            "paired performance and",
            "completion-marker reuse",
            "gnostikon-workflow-control",
            "python -m unittest discover -s tests -v",
            "python -m sphinx -W -b html docs docs/_build/html",
        ]:
            with self.subTest(token=token):
                self.assertIn(token, acceptance)

    def test_arm64_image_evidence_and_scientific_validation_are_release_blockers(self):
        acceptance = read("docs/phase4-acceptance.rst")
        for token in [
            "linux/amd64",
            "linux/arm64",
            "executable smoke-test output",
            "bill of materials",
            "poikilognostikon-somatic-hts",
            "poikilognostikon-somatic-clairs-to",
            "poikilognostikon-somatic-clairs",
            "poikilognostikon-somatic-clair3-helper",
            "poikilognostikon-somatic-severus",
            "poikilognostikon-somatic-modkit",
            "poikilognostikon-somatic-dss",
            "poikilognostikon-somatic-phasing",
            "poikilognostikon-somatic-annotation",
            "poikilognostikon-somatic-helpers",
            "ClairS-TO tumour-only SNV/indel calling must be concordance-tested",
            "Paired ClairS candidate extraction",
            "somatic_germline_helper",
            "WhatsHap phasing and haplotagging",
            "Severus tumour-only SV calling must be concordance-tested",
            "Modkit role aggregation must be checked",
            "DSS differential methylation",
            "SnpEff/SnpSift annotation must be checked",
            "Reference/genome-build validation must be checked",
            "Scientific validation remains unresolved for ClairS-TO tumour-only",
        ]:
            with self.subTest(token=token):
                self.assertIn(token, acceptance)

    def test_release_blockers_cover_somatic_import_failures(self):
        acceptance = read("docs/phase4-acceptance.rst")
        for token in [
            "bam_normal",
            "missing-normal inference",
            "pair_id",
            "relationship_snapshot_digest",
            "somatic_small_variant",
            "somatic_structural_variant",
            "duplicate somatic ingress",
            "monolithic ``main.nf``",
            "hidden normal/control requirements",
            "ONT runtime containers",
            "sha-like tags",
            "clairs_args",
            "severus_args",
            "modkit_args",
            "HTML reports",
            "IGV surfaces",
            "OPTIONAL_FILE",
            "collect()",
            "combine()",
            "first()",
            "groupTuple()",
            "container digest",
            "option digest",
            "completion-marker provenance",
        ]:
            with self.subTest(token=token):
                self.assertIn(token, acceptance)


if __name__ == "__main__":
    unittest.main()
