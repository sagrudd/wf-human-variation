"""Release acceptance gates for phase 2 task 25."""

from __future__ import annotations

import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (REPO_ROOT / path).read_text()


class Phase2ReleaseAcceptanceTest(unittest.TestCase):
    def test_release_acceptance_page_is_in_sphinx_canon(self):
        index = read("docs/index.rst")
        acceptance = read("docs/release-acceptance.rst")

        self.assertIn("release-acceptance", index)
        self.assertIn("Phase 2 Release Acceptance", acceptance)
        self.assertIn("maintained Poikilognostikon execution backend", acceptance)

    def test_acceptance_checklist_covers_phase_2_minimum_criteria(self):
        acceptance = read("docs/release-acceptance.rst")
        criteria = [
            "No workflow-generated EPI2ME analysis HTML reports",
            "No report-only Python code on the runtime path",
            "No hidden feature activation for STR, Spectre, or phased methylation in",
            "Bounded contracts exist for mapping, aggregation/QC, SNP, SV, CNV, STR,",
            "Synthetic tests cover local fixture and sample identity contracts",
            "Retained outputs are documented accurately",
            "Poikilognostikon can schedule bounded work from manifest state",
            "Performance and resumability gates are active",
        ]
        for criterion in criteria:
            with self.subTest(criterion=criterion):
                self.assertIn(criterion, acceptance)

    def test_remaining_debt_is_finite_named_and_not_expanded(self):
        acceptance = read("docs/release-acceptance.rst")
        expected_debt = [
            "Anonymous compatibility graph",
            "Broad channel joins and collections",
            "Legacy optional-file boundary helper",
            "Legacy sample-sheet/bootstrap ingress",
            "Legacy launch-time feature coupling",
            "Compatibility SNP/SV/CNV/STR/methylation/reporting subworkflows",
            "Partner export and publication joins",
        ]
        for debt in expected_debt:
            with self.subTest(debt=debt):
                self.assertIn(debt, acceptance)

        self.assertIn("``main.nf``", acceptance)
        self.assertIn("``docs/keyed-joins.rst`` Task 22 inventory", acceptance)
        self.assertIn("must not be expanded", acceptance)
        self.assertIn("timeline.html", acceptance)
        self.assertIn("not EPI2ME analysis reports", acceptance)

    def test_release_blockers_match_active_static_gates(self):
        acceptance = read("docs/release-acceptance.rst")
        performance_gate = read("tests/test_phase2_performance_gates.py")
        bounded_gate = read("tests/test_bounded_entry_contract.py")

        for token in [
            ".html",
            "ezcharts",
            "OPTIONAL_FILE",
            "params\\.wf",
            ".collect(",
            ".combine(",
            "groupTuple(",
        ]:
            with self.subTest(token=token):
                self.assertIn(token, performance_gate)
        for token in ["params.wf", ".collect()", ".combine()"]:
            with self.subTest(acceptance_token=token):
                self.assertIn(token, acceptance)
        self.assertIn("snp(", bounded_gate)
        self.assertIn("str(", bounded_gate)
        self.assertIn("cnv_spectre(", bounded_gate)
        self.assertIn("validate_modbam(", bounded_gate)

    def test_required_local_release_gate_is_documented(self):
        acceptance = read("docs/release-acceptance.rst")
        for command in [
            "python -m unittest discover -s tests -v",
            "python -m sphinx -W -b html docs docs/_build/html",
            "python -m json.tool nextflow_schema.json",
            "python -m json.tool output_definition.json",
        ]:
            with self.subTest(command=command):
                self.assertIn(command, acceptance)


if __name__ == "__main__":
    unittest.main()
