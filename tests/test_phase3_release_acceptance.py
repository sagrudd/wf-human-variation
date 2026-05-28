"""Release acceptance gates for phase 3 task 25."""

from __future__ import annotations

import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (REPO_ROOT / path).read_text()


class Phase3ReleaseAcceptanceTest(unittest.TestCase):
    def test_phase3_acceptance_page_is_in_sphinx_canon(self):
        index = read("docs/index.rst")
        acceptance = read("docs/phase3-acceptance.rst")

        self.assertIn("phase3-acceptance", index)
        self.assertIn("Phase 3 Family Acceptance", acceptance)
        self.assertIn("implementation-complete for local contract review only", acceptance)
        self.assertIn("not release-accepted for customer or production use", acceptance)
        self.assertIn("b1a5a78ec9c02de276f01dc8608096db93a87e91", acceptance)
        self.assertIn("not an accepted fork pin while phase-3 files remain uncommitted", acceptance)

    def test_required_family_task_families_are_named(self):
        acceptance = read("docs/phase3-acceptance.rst")
        for task_family in [
            "family_germline_snp",
            "family_germline_snp_denovo",
            "family_germline_snp_merge",
            "family_joint_genotyping",
            "family_pedigree_phasing",
            "family_haplotagging",
            "family_sv_calling",
            "family_sv_merging",
            "family_mendelian_assessment",
        ]:
            with self.subTest(task_family=task_family):
                self.assertIn(f"``{task_family}``", acceptance)

    def test_minimum_contract_and_synthetic_gates_are_documented(self):
        acceptance = read("docs/phase3-acceptance.rst")
        for token in [
            "tests/test_bounded_entry_contract.py",
            "tests/test_phase3_family_performance_gates.py",
            "tests/test_phase2_synthetic_contracts.py",
            "PED bootstrap replay",
            "late parent",
            "family completion-marker reuse",
            "gnostikon-workflow-control",
            "python -m unittest discover -s tests -v",
            "python -m sphinx -W -b html docs docs/_build/html",
        ]:
            with self.subTest(token=token):
                self.assertIn(token, acceptance)

    def test_arm64_image_evidence_and_scientific_validation_are_release_blockers(self):
        acceptance = read("docs/phase3-acceptance.rst")
        for token in [
            "linux/amd64",
            "linux/arm64",
            "executable smoke-test output",
            "bill of materials",
            "poikilognostikon-clair3-nova",
            "poikilognostikon-trio-hts",
            "poikilognostikon-trio-joint",
            "poikilognostikon-trio-phasing",
            "poikilognostikon-trio-sv",
            "Clair3-Nova candidate selection and denovo calling must be concordance-tested",
            "GLnexus joint genotyping must be concordance-tested",
            "WhatsHap pedigree phasing and haplotagging must be validated",
            "Sniffles2 per-member SNF generation and family SV merging must be validated",
            "RTG Mendelian assessment must be validated",
            "Scientific validation remains unresolved for Clair3-Nova candidate/denovo concordance",
            "GLnexus joint-genotyping concordance",
            "Sniffles2 per-member SNF and joint SV merge concordance",
        ]:
            with self.subTest(token=token):
                self.assertIn(token, acceptance)

    def test_release_blockers_match_family_barrier_and_provenance_gates(self):
        acceptance = read("docs/phase3-acceptance.rst")
        performance_gate = read("tests/test_phase3_family_performance_gates.py")
        for token in [
            "collect()",
            "combine()",
            "first()",
            "groupTuple()",
            "OPTIONAL_FILE",
            "HTML report",
            "container digest",
            "model checksum",
            "completion-marker provenance",
        ]:
            with self.subTest(token=token):
                self.assertIn(token, acceptance)
        for token in [
            "collect\\s*\\(",
            "combine\\s*\\(",
            "first\\s*\\(",
            "groupTuple\\s*\\(",
            "OPTIONAL_FILE",
            "optionalBoundaryChannel()",
        ]:
            with self.subTest(token=token):
                self.assertIn(token, performance_gate)


if __name__ == "__main__":
    unittest.main()
