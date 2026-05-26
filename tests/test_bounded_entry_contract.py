"""Static contract tests for bounded Nextflow entry points."""

from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]


def read(path):
    """Read a repository file."""
    return (REPO_ROOT / path).read_text()


class BoundedEntryContractTest(unittest.TestCase):
    """Verify bounded entries stay separate from the compatibility graph."""

    def test_bounded_entries_are_registered_without_default_graph_initialisation(self):
        main = read("main.nf")

        self.assertIn("workflow mapping {", main)
        self.assertIn("boundedMappingEntryParams(params)", main)
        self.assertIn("runBoundedMappingTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.input_xam, checkIfExists: true)", main)
        self.assertIn("Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)", main)
        self.assertIn("workflow sample_aggregation {", main)
        self.assertIn("boundedSampleAggregationEntryParams(params)", main)
        self.assertIn("runBoundedSampleAggregationTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.mapped_xam, checkIfExists: true)", main)
        self.assertIn("Channel.fromPath(entry_contract.reference_index, checkIfExists: true)", main)
        self.assertIn("workflow variant_calling {", main)
        self.assertIn("boundedVariantCallingEntryParams(params)", main)
        self.assertIn("runBoundedSmallVariantTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.aggregate_xam, checkIfExists: true)", main)
        self.assertIn("Channel.fromPath(entry_contract.clair3_model, type: \"dir\", checkIfExists: true)", main)
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

    def test_sample_aggregation_entry_does_not_launch_compatibility_ingress_or_analysis(self):
        main = read("main.nf")
        sample_aggregation_entry = main.split("workflow sample_aggregation {", 1)[1].split(
            "// Compatibility entrypoint workflow", 1
        )[0]

        forbidden = [
            "ingress(",
            "prepare_reference(",
            "readStats(",
            "mosdepth_input(",
            "publish_artifact(",
            "combine_metrics_json(",
            "snp(",
            "sv(",
            "cnv_spectre(",
            "str(",
        ]
        for token in forbidden:
            with self.subTest(token=token):
                self.assertNotIn(token, sample_aggregation_entry)

    def test_variant_calling_entry_does_not_launch_compatibility_graph_or_reports(self):
        main = read("main.nf")
        variant_entry = main.split("workflow variant_calling {", 1)[1].split(
            "// Compatibility entrypoint workflow", 1
        )[0]

        forbidden = [
            "ingress(",
            "prepare_reference(",
            "snp(",
            "snp_stats(",
            "output_snp(",
            "refine_with_sv(",
            "annotate_snp_vcf(",
            "sv(",
            "cnv_spectre(",
            "str(",
            "publish_artifact(",
            "combine_metrics_json(",
        ]
        for token in forbidden:
            with self.subTest(token=token):
                self.assertNotIn(token, variant_entry)

    def test_bounded_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_mapping.nf")

        for param in [
            "task_family",
            "task_key",
            "task_dir",
            "task_cache_dir",
            "completion_marker_path",
            "output_paths",
            "sample_id",
            "input_xam",
            "input_kind",
            "input_digest",
            "reference_fasta",
            "reference_id",
            "mapper",
            "mapper_options_digest",
            "container_digest",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        self.assertIn("wf-human-variation.bounded_mapping.v1", helper)
        self.assertIn('"mapped_xam"', helper)
        self.assertIn('"mapped_xam_index"', helper)
        self.assertIn('"alignment_metadata"', helper)
        self.assertIn('"run_ids"', helper)
        self.assertIn('"mapper_provenance"', helper)
        self.assertIn('"qc_stats"', helper)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertIn("bamstats ${out_xam}", module)
        self.assertIn("workflow-glue check_sq_ref", module)
        self.assertIn("workflow-glue check_mapped_reads", module)
        self.assertIn("minimap2 -y", module)

    def test_sample_aggregation_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_sample_aggregation.nf")

        for param in [
            "task_family",
            "task_key",
            "task_dir",
            "task_cache_dir",
            "completion_marker_path",
            "output_paths",
            "sample_id",
            "mapped_xam",
            "mapped_xam_index",
            "mapped_xam_digest",
            "reference_fasta",
            "reference_index",
            "reference_id",
            "aggregation_config_digest",
            "coverage_config_digest",
            "container_digest",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"aggregate_xam"',
            '"aggregate_xam_index"',
            '"readstats"',
            '"flagstat"',
            '"run_ids"',
            '"basecallers"',
            '"mosdepth_summary"',
            '"mosdepth_regions"',
            '"mosdepth_distribution"',
            '"mosdepth_thresholds"',
            '"coverage_state"',
            '"qc_stats"',
            '"aggregation_manifest"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn("wf-human-variation.bounded_sample_aggregation.v1", helper)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertIn("bamstats -", module)
        self.assertIn("mosdepth -x", module)
        self.assertIn("workflow-glue check_mapped_reads", module)
        self.assertIn('"state": coverage_status', module)
        self.assertIn('"coverage_state": coverage_status', module)
        self.assertIn('"coverage_state": coverage_state', module)
        self.assertIn('"rejected_low_coverage"', module)

    def test_variant_calling_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_variant_calling.nf")

        for param in [
            "task_family",
            "task_key",
            "task_dir",
            "task_cache_dir",
            "completion_marker_path",
            "output_paths",
            "sample_id",
            "aggregate_xam",
            "aggregate_xam_index",
            "aggregate_xam_digest",
            "reference_fasta",
            "reference_index",
            "reference_id",
            "clair3_model",
            "clair3_model_digest",
            "variant_mode",
            "variant_config_digest",
            "container_digest",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"snp_vcf"',
            '"snp_vcf_index"',
            '"snp_gvcf"',
            '"snp_gvcf_index"',
            '"structural_variant_vcf"',
            '"structural_variant_vcf_index"',
            '"structural_variant_snf"',
            '"variant_calling_manifest"',
            '"variant_calling_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn("wf-human-variation.bounded_variant_calling.v1", helper)
        self.assertIn('"snp"', helper)
        self.assertIn('"snp_gvcf"', helper)
        self.assertIn('"sv"', helper)
        self.assertIn("variant_mode 'snp_gvcf' requires variant_options.emit_gvcf=true", helper)
        self.assertIn("target_bed and genotyping_vcf are mutually exclusive", helper)
        self.assertIn("unsupported variant calling option(s)", helper)
        self.assertIn("unsupported structural variant option(s)", helper)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertIn("run_clair3.sh", module)
        self.assertIn('path "snp.gvcf.gz", optional: true', module)
        self.assertIn('"tool": "clair3"', module)
        self.assertIn('"phased_snp_vcf": {"requested": False', module)
        self.assertIn('"haplotagged_contig_bams": {"requested": False', module)
        self.assertNotIn("output_snp", module)
        self.assertNotIn("makeReport", module)

    def test_structural_variant_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_structural_variant_calling.nf")
        main = read("main.nf")

        for param in [
            "mosdepth_summary",
            "target_bed",
            "structural_variant_options",
            "cluster_merge_pos",
            "min_sv_length",
            "min_read_support",
            "min_read_support_limit",
            "chromosome_codes",
            "sniffles_options",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        self.assertIn('if (entry_contract.variant_mode == "sv")', main)
        self.assertIn("runBoundedStructuralVariantTask", main)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertIn("sniffles", module)
        self.assertIn("get_filter_calls_command.py", module)
        self.assertIn("bcftools sort", module)
        self.assertIn('path "structural_variant.vcf.gz"', module)
        self.assertIn('path "structural_variant.vcf.gz.tbi"', module)
        self.assertIn('path "structural_variant.snf"', module)
        self.assertIn('"tool": "sniffles2"', module)
        self.assertIn('"sv_benchmark": {"requested": False', module)
        self.assertIn("deferred_machine_readable_evaluation_contract", module)
        self.assertNotIn("makeReport", module)
        self.assertNotIn("output_sv", module)

    def test_mapping_entry_declares_supported_input_kinds_and_allowlisted_mapper_options(self):
        helper = read("lib/bounded_entry.nf")

        for token in [
            '"bam"',
            '"cram"',
            '"ubam"',
            '"basecalled_bam"',
            '"minimap2"',
            '"minimap2_preset"',
            '"cap_kalloc"',
            '"cap_sw_mem"',
            '"fastq_threads"',
            '"map_threads"',
            '"sort_threads"',
            '"bamstats_threads"',
        ]:
            with self.subTest(token=token):
                self.assertIn(token, helper)

        self.assertIn("unsupported mapping option(s)", helper)

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
        self.assertIn("``-entry sample_aggregation``", docs)
        self.assertIn("``-entry variant_calling``", docs)
        self.assertIn("bounded mapping entry", docs)
        self.assertIn("bounded sample aggregation entry", docs)
        self.assertIn("bounded small-variant entry", docs)
        self.assertIn("bounded structural-variant entry", docs)
        self.assertIn("Task 15", docs)
        self.assertIn("Task 16", docs)
        self.assertIn("Task 17", docs)
        self.assertIn("Task 18", docs)
        self.assertIn("mapped_xam", docs)
        self.assertIn("coverage_state", docs)
        self.assertIn("snp_vcf", docs)
        self.assertIn("structural_variant_vcf", docs)
        self.assertIn("mapping bounded entry", ledger)
        self.assertIn("sample aggregation bounded entry", ledger)
        self.assertIn("small-variant bounded entry", ledger)
        self.assertIn("structural-variant bounded entry", ledger)


if __name__ == "__main__":
    unittest.main()
