"""Static contract tests for bounded Nextflow entry points."""

from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]


def read(path):
    """Read a repository file."""
    return (REPO_ROOT / path).read_text()


class BoundedEntryContractTest(unittest.TestCase):
    """Verify bounded entries stay separate from the compatibility graph."""

    def test_mapping_entry_is_registered_without_default_graph_initialisation(self):
        main = read("main.nf")

        self.assertIn("workflow mapping {", main)
        self.assertIn('boundedEntryParams(params, "mapping", "mapping")', main)
        self.assertIn("writeMappingEntryContract(", main)
        self.assertIn("// Compatibility entrypoint workflow\nworkflow {\n    WorkflowMain.initialise", main)
        self.assertNotIn("// entrypoint workflow\nWorkflowMain.initialise", main)

    def test_mapping_entry_does_not_launch_compatibility_ingress_or_analysis(self):
        main = read("main.nf")
        mapping_entry = main.split("workflow mapping {", 1)[1].split("// Compatibility entrypoint workflow", 1)[0]

        forbidden = [
            "ingress(",
            "prepare_reference(",
            "readStats(",
            "snp(",
            "sv(",
            "cnv_spectre(",
            "str(",
        ]
        for token in forbidden:
            with self.subTest(token=token):
                self.assertNotIn(token, mapping_entry)

    def test_bounded_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_entry.nf")

        for param in [
            "task_family",
            "task_key",
            "task_dir",
            "task_cache_dir",
            "completion_marker_path",
            "output_paths",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        self.assertIn("wf-human-variation.bounded_entry.v1", helper)
        self.assertIn("output_paths.bounded_launch_contract", helper)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertIn('"analysis_status": "not_implemented_scaffold"', module)

    def test_bounded_entry_docs_and_ledger_are_current(self):
        docs = "\n".join(
            read(path)
            for path in [
                "docs/overview.rst",
                "docs/controller-execution.rst",
                "docs/architecture.rst",
                "docs/bounded-task-families.rst",
                "docs/maintenance.rst",
            ]
        )
        ledger = read("docs/maintenance.rst") + "\n" + read("docs/controller-execution.rst")

        self.assertIn("``-entry mapping``", docs)
        self.assertIn("bounded launch-contract scaffold", docs)
        self.assertIn("Task 15", docs)
        self.assertIn("mapping bounded entry scaffold", ledger)


if __name__ == "__main__":
    unittest.main()
