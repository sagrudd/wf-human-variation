"""Performance and resumability regression gates for phase 2 task 24."""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (REPO_ROOT / path).read_text()


def runtime_files() -> list[Path]:
    roots = ["main.nf", "workflows", "modules", "lib", "bin"]
    files: list[Path] = []
    for root in roots:
        path = REPO_ROOT / root
        if path.is_file():
            files.append(path)
        else:
            files.extend(candidate for candidate in path.rglob("*") if candidate.is_file() and "__pycache__" not in candidate.parts)
    return sorted(files)


class Phase2PerformanceGateTest(unittest.TestCase):
    def test_public_outputs_and_runtime_do_not_reintroduce_html_reports(self):
        for relative in ("output_definition.json", "nextflow_schema.json"):
            data = json.loads((REPO_ROOT / relative).read_text())
            flat_values = list(self._flatten_values(data))
            self.assertNotIn("output_report", self._flatten_keys(data))
            self.assertFalse(
                [value for value in flat_values if isinstance(value, str) and value.lower().endswith((".html", ".htm"))],
                relative,
            )

        runtime = "\n".join(path.read_text(errors="ignore") for path in runtime_files())
        for token in [
            "makeReport(",
            "report_html",
            "wf-human-alignment-report.html",
            "wf-human-snp-report.html",
            "wf-human-sv-report.html",
            "wf-human-cnv-report.html",
            "wf-human-str-report.html",
        ]:
            with self.subTest(token=token):
                self.assertNotIn(token, runtime)

    def test_report_only_python_dependencies_are_not_imported_by_runtime_code(self):
        runtime = "\n".join(path.read_text(errors="ignore") for path in runtime_files())
        forbidden_imports = [
            r"^\s*import\s+ezcharts\b",
            r"^\s*from\s+ezcharts\b",
            r"^\s*import\s+dominate\b",
            r"^\s*from\s+dominate\b",
            r"^\s*import\s+bokeh\b",
            r"^\s*from\s+bokeh\b",
            r"^\s*import\s+aplanat\b",
            r"^\s*from\s+aplanat\b",
        ]
        for pattern in forbidden_imports:
            with self.subTest(pattern=pattern):
                self.assertIsNone(re.search(pattern, runtime, flags=re.MULTILINE))

    def test_absent_input_consumers_are_centralized_at_boundary_helper(self):
        """Block absent-input marker consumers outside the boundary helper."""
        offenders = []
        for path in runtime_files():
            relative = path.relative_to(REPO_ROOT).as_posix()
            if relative == "lib/optional_inputs.nf":
                continue
            text = path.read_text(errors="ignore")
            if "OPTIONAL_FILE" in text or "__wf_human_variation_absent_input__" in text:
                offenders.append(relative)

        self.assertEqual(offenders, [])

    def test_params_wf_runtime_mutation_is_not_reintroduced(self):
        mutation = re.compile(r"params\.wf(?:\[[^\]]+\]|\.[A-Za-z0-9_]+)\s*=")
        offenders = []
        for path in runtime_files():
            relative = path.relative_to(REPO_ROOT).as_posix()
            for line_number, line in enumerate(path.read_text(errors="ignore").splitlines(), start=1):
                if mutation.search(line):
                    offenders.append(f"{relative}:{line_number}:{line.strip()}")

        self.assertEqual(offenders, [])

    def test_performance_sensitive_joins_are_documented_for_review(self):
        docs = read("docs/keyed-joins.rst")
        documented_files = {
            "main.nf",
            "workflows/wf-human-snp.nf",
            "workflows/wf-human-str.nf",
            "workflows/methyl.nf",
            "workflows/wf-human-cnv.nf",
            "workflows/partners.nf",
        }
        observed_files = set()
        for path in [REPO_ROOT / "main.nf", *sorted((REPO_ROOT / "workflows").glob("*.nf"))]:
            text = path.read_text()
            if ".collect(" in text or ".combine(" in text or ".first(" in text or "groupTuple(" in text:
                observed_files.add(path.relative_to(REPO_ROOT).as_posix())

        self.assertTrue(observed_files)
        self.assertTrue(observed_files <= documented_files, sorted(observed_files - documented_files))
        for relative in observed_files:
            self.assertIn(f"``{relative}``", docs)

    def test_task_cache_behaviour_is_recorded_in_documentation(self):
        docs = read("docs/idempotency.rst")
        required = [
            "Schedulers must check for a valid completion marker before queuing work.",
            "Successful old work with the same task key remains reusable.",
            "If required outputs are removed or the marker belongs to a different task key",
            "``--force-refresh``",
        ]
        for token in required:
            with self.subTest(token=token):
                self.assertIn(token, docs)

    @classmethod
    def _flatten_keys(cls, value: object) -> set[str]:
        if isinstance(value, dict):
            keys = set(value)
            for item in value.values():
                keys.update(cls._flatten_keys(item))
            return keys
        if isinstance(value, list):
            keys: set[str] = set()
            for item in value:
                keys.update(cls._flatten_keys(item))
            return keys
        return set()

    @classmethod
    def _flatten_values(cls, value: object):
        if isinstance(value, dict):
            for item in value.values():
                yield from cls._flatten_values(item)
        elif isinstance(value, list):
            for item in value:
                yield from cls._flatten_values(item)
        else:
            yield value


if __name__ == "__main__":
    unittest.main()
