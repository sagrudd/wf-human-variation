"""Static contract tests for bounded Nextflow entry points."""

from pathlib import Path
import re
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
        self.assertIn("workflow somatic_germline_helper {", main)
        self.assertIn("boundedSomaticGermlineHelperEntryParams(params)", main)
        self.assertIn("runBoundedSomaticGermlineHelperTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.helper_aggregate_xam, checkIfExists: true)", main)
        self.assertIn("workflow somatic_phasing {", main)
        self.assertIn("boundedSomaticPhasingEntryParams(params)", main)
        self.assertIn("runBoundedSomaticPhasingTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.input_vcf, checkIfExists: true)", main)
        self.assertIn("workflow somatic_haplotagging {", main)
        self.assertIn("boundedSomaticHaplotaggingEntryParams(params)", main)
        self.assertIn("runBoundedSomaticHaplotaggingTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.somatic_phased_vcf, checkIfExists: true)", main)
        self.assertIn("workflow family_germline_snp {", main)
        self.assertIn("boundedFamilyGermlineSnpEntryParams(params)", main)
        self.assertIn("runBoundedTrioCandidateSelectionTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.proband_snp_vcf, checkIfExists: true)", main)
        self.assertIn("Channel.fromPath(entry_contract.clair3_nova_model, type: \"dir\", checkIfExists: true)", main)
        self.assertIn("workflow family_germline_snp_denovo {", main)
        self.assertIn("boundedFamilyGermlineSnpDenovoEntryParams(params)", main)
        self.assertIn("runBoundedTrioDenovoCallingTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.trio_candidate_beds, type: \"dir\", checkIfExists: true)", main)
        self.assertIn("Channel.fromPath(entry_contract.proband_bam, checkIfExists: true)", main)
        self.assertIn("workflow family_germline_snp_merge {", main)
        self.assertIn("boundedFamilyGermlineSnpMergeEntryParams(params)", main)
        self.assertIn("runBoundedTrioMergeSortTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.trio_denovo_vcf_fragments, type: \"dir\", checkIfExists: true)", main)
        self.assertIn("Channel.fromPath(entry_contract.snp_gvcf, checkIfExists: true)", main)
        self.assertIn("workflow family_joint_genotyping {", main)
        self.assertIn("boundedFamilyJointGenotypingEntryParams(params)", main)
        self.assertIn("runBoundedFamilyJointGenotypingTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.proband_snp_gvcf, checkIfExists: true)", main)
        self.assertIn("Channel.fromPath(entry_contract.glnexus_config, checkIfExists: true)", main)
        self.assertIn("workflow family_pedigree_phasing {", main)
        self.assertIn("boundedFamilyPedigreePhasingEntryParams(params)", main)
        self.assertIn("runBoundedFamilyPedigreePhasingTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.family_joint_vcf, checkIfExists: true)", main)
        self.assertIn("Channel.fromPath(entry_contract.proband_bam, checkIfExists: true)", main)
        self.assertIn("workflow family_haplotagging {", main)
        self.assertIn("boundedFamilyHaplotaggingEntryParams(params)", main)
        self.assertIn("runBoundedFamilyHaplotaggingTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.pedigree_filtered_vcf, checkIfExists: true)", main)
        self.assertIn("Channel.fromPath(entry_contract.proband_xam, checkIfExists: true)", main)
        self.assertIn("workflow family_sv_calling {", main)
        self.assertIn("boundedFamilySvCallingEntryParams(params)", main)
        self.assertIn("runBoundedFamilySvCallingTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.aggregate_xam, checkIfExists: true)", main)
        self.assertIn("Channel.fromPath(entry_contract.mosdepth_summary, checkIfExists: true)", main)
        self.assertIn("workflow family_sv_merging {", main)
        self.assertIn("boundedFamilySvMergingEntryParams(params)", main)
        self.assertIn("runBoundedFamilySvMergingTask(", main)
        self.assertIn("entry_contract.proband_snf ? Channel.fromPath(entry_contract.proband_snf", main)
        self.assertIn("workflow family_mendelian_assessment {", main)
        self.assertIn("boundedFamilyMendelianAssessmentEntryParams(params)", main)
        self.assertIn("runBoundedFamilyMendelianAssessmentTask(", main)
        self.assertIn("entry_contract.family_joint_vcf ? Channel.fromPath(entry_contract.family_joint_vcf", main)
        self.assertIn("Channel.fromPath(entry_contract.reference_sdf, type: \"dir\", checkIfExists: true)", main)
        self.assertIn("workflow somatic_tumour_only_snv {", main)
        self.assertIn("boundedSomaticTumourOnlySnvEntryParams(params)", main)
        self.assertIn("runBoundedSomaticTumourOnlySnvTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.aggregate_xam, checkIfExists: true)", main)
        self.assertIn("Channel.fromPath(entry_contract.clairs_to_model, type: \"dir\", checkIfExists: true)", main)
        self.assertIn("workflow somatic_paired_snv_candidate {", main)
        self.assertIn("boundedSomaticPairedSnvCandidateEntryParams(params)", main)
        self.assertIn("runBoundedSomaticPairedSnvCandidateTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.tumour_aggregate_xam, checkIfExists: true)", main)
        self.assertIn("Channel.fromPath(entry_contract.clairs_reference_bundle, type: \"dir\", checkIfExists: true)", main)
        self.assertIn("workflow somatic_paired_snv_pileup {", main)
        self.assertIn("boundedSomaticPairedSnvPileupEntryParams(params)", main)
        self.assertIn("runBoundedSomaticPairedSnvPileupTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.candidate_bed, checkIfExists: true)", main)
        self.assertIn("workflow somatic_paired_snv_full_alignment {", main)
        self.assertIn("boundedSomaticPairedSnvFullAlignmentEntryParams(params)", main)
        self.assertIn("runBoundedSomaticPairedSnvFullAlignmentTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.tumour_alignment_xam, checkIfExists: true)", main)
        self.assertIn("workflow somatic_paired_snv_merge {", main)
        self.assertIn("boundedSomaticPairedSnvMergeEntryParams(params)", main)
        self.assertIn("runBoundedSomaticPairedSnvMergeTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.pileup_prediction_fragments, type: \"dir\", checkIfExists: true)", main)
        self.assertIn("workflow somatic_qc {", main)
        self.assertIn("boundedSomaticQcEntryParams(params)", main)
        self.assertIn("runBoundedSomaticQcTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.tumour_mosdepth_regions, checkIfExists: true)", main)
        self.assertIn("Channel.fromPath(entry_contract.normal_or_control_mosdepth_regions, checkIfExists: true)", main)
        self.assertIn("workflow somatic_tumour_only_sv {", main)
        self.assertIn("boundedSomaticTumourOnlySvEntryParams(params)", main)
        self.assertIn("runBoundedSomaticTumourOnlySvTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.aggregate_xam, checkIfExists: true)", main)
        self.assertIn("Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)", main)
        self.assertIn("workflow somatic_annotation {", main)
        self.assertIn("boundedSomaticAnnotationEntryParams(params)", main)
        self.assertIn("runBoundedSomaticAnnotationTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.source_vcf, checkIfExists: true)", main)
        self.assertIn("Channel.fromPath(entry_contract.snpeff_database, type: \"dir\", checkIfExists: true)", main)
        self.assertIn("workflow somatic_methylation_aggregation {", main)
        self.assertIn("boundedSomaticMethylationAggregationEntryParams(params)", main)
        self.assertIn("runBoundedSomaticMethylationAggregationTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.role_aggregate_xam, checkIfExists: true)", main)
        self.assertIn("workflow cnv {", main)
        self.assertIn("boundedCnvEntryParams(params)", main)
        self.assertIn("runBoundedSpectreCnvTask(", main)
        self.assertIn("runBoundedQdnaseqCnvTask(", main)
        self.assertIn("workflow str {", main)
        self.assertIn("boundedStrEntryParams(params)", main)
        self.assertIn("runBoundedStrTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.haplotagged_contig_manifest, checkIfExists: true)", main)
        self.assertIn("Channel.fromPath(entry_contract.repeat_bed, checkIfExists: true)", main)
        self.assertIn("workflow methylation {", main)
        self.assertIn("boundedMethylationEntryParams(params)", main)
        self.assertIn("runBoundedMethylationTask(", main)
        self.assertIn("Channel.fromPath(entry_contract.aggregate_xam, checkIfExists: true)", main)
        self.assertIn("entry_contract.methylation_mode == \"phased\"", main)
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

    def test_family_germline_snp_entry_does_not_launch_compatibility_graph_or_reports(self):
        main = read("main.nf")
        family_entry = main.split("workflow family_germline_snp {", 1)[1].split(
            "// Compatibility entrypoint workflow", 1
        )[0]

        forbidden = [
            "ingress(",
            "prepare_reference(",
            "snp(",
            "snp_stats(",
            "output_snp(",
            "runBoundedSmallVariantTask(",
            "runBoundedStructuralVariantTask(",
            "cnv_spectre(",
            "str(",
            "publish_artifact(",
            "combine_metrics_json(",
            "makeReport",
        ]
        for token in forbidden:
            with self.subTest(token=token):
                self.assertNotIn(token, family_entry)

    def test_family_germline_snp_denovo_entry_does_not_launch_compatibility_graph_or_reports(self):
        main = read("main.nf")
        family_entry = main.split("workflow family_germline_snp_denovo {", 1)[1].split(
            "// Compatibility entrypoint workflow", 1
        )[0]

        forbidden = [
            "ingress(",
            "prepare_reference(",
            "snp(",
            "snp_stats(",
            "output_snp(",
            "runBoundedSmallVariantTask(",
            "runBoundedStructuralVariantTask(",
            "cnv_spectre(",
            "str(",
            "publish_artifact(",
            "combine_metrics_json(",
            "makeReport",
            "SelectCandidates_Trio",
        ]
        for token in forbidden:
            with self.subTest(token=token):
                self.assertNotIn(token, family_entry)

    def test_family_germline_snp_merge_entry_does_not_launch_compatibility_graph_or_reports(self):
        main = read("main.nf")
        family_entry = main.split("workflow family_germline_snp_merge {", 1)[1].split(
            "// Compatibility entrypoint workflow", 1
        )[0]

        forbidden = [
            "ingress(",
            "prepare_reference(",
            "snp(",
            "snp_stats(",
            "output_snp(",
            "runBoundedSmallVariantTask(",
            "runBoundedStructuralVariantTask(",
            "cnv_spectre(",
            "str(",
            "publish_artifact(",
            "combine_metrics_json(",
            "makeReport",
            "CallVarBam_Denovo",
            "SelectCandidates_Trio",
        ]
        for token in forbidden:
            with self.subTest(token=token):
                self.assertNotIn(token, family_entry)

    def test_family_joint_genotyping_entry_does_not_launch_compatibility_graph_or_reports(self):
        main = read("main.nf")
        family_entry = main.split("workflow family_joint_genotyping {", 1)[1].split(
            "// Compatibility entrypoint workflow", 1
        )[0]

        forbidden = [
            "ingress(",
            "prepare_reference(",
            "snp(",
            "snp_stats(",
            "output_snp(",
            "runBoundedSmallVariantTask(",
            "runBoundedTrioMergeSortTask(",
            "cnv_spectre(",
            "str(",
            "publish_artifact(",
            "combine_metrics_json(",
            "makeReport",
            "rtgTools(",
            "phase_joint_trio(",
        ]
        for token in forbidden:
            with self.subTest(token=token):
                self.assertNotIn(token, family_entry)

    def test_family_pedigree_phasing_entry_does_not_launch_compatibility_graph_or_reports(self):
        main = read("main.nf")
        family_entry = main.split("workflow family_pedigree_phasing {", 1)[1].split(
            "// Compatibility entrypoint workflow", 1
        )[0]

        forbidden = [
            "ingress(",
            "prepare_reference(",
            "snp(",
            "snp_stats(",
            "output_snp(",
            "runBoundedSmallVariantTask(",
            "runBoundedFamilyJointGenotypingTask(",
            "cnv_spectre(",
            "str(",
            "publish_artifact(",
            "combine_metrics_json(",
            "makeReport",
            "rtgTools(",
            "haplotag_trio(",
        ]
        for token in forbidden:
            with self.subTest(token=token):
                self.assertNotIn(token, family_entry)

    def test_cnv_entry_does_not_launch_compatibility_graph_or_reports(self):
        main = read("main.nf")
        cnv_entry = main.split("workflow cnv {", 1)[1].split(
            "// Compatibility entrypoint workflow", 1
        )[0]

        forbidden = [
            "ingress(",
            "prepare_reference(",
            "snp(",
            "cnv_spectre(",
            "cnv_qdnaseq(",
            "output_cnv(",
            "annotate_vcf(",
            "combine_metrics_json(",
            "publish_artifact(",
            "str(",
        ]
        for token in forbidden:
            with self.subTest(token=token):
                self.assertNotIn(token, cnv_entry)

    def test_somatic_tumour_only_snv_entry_does_not_launch_compatibility_graph_or_reports(self):
        main = read("main.nf")
        somatic_entry = main.split("workflow somatic_tumour_only_snv {", 1)[1].split(
            "// Compatibility entrypoint workflow", 1
        )[0]

        forbidden = [
            "ingress(",
            "prepare_reference(",
            "snp(",
            "sv(",
            "cnv_spectre(",
            "str(",
            "output_snp(",
            "combine_metrics_json(",
            "publish_artifact(",
            "makeReport",
            "bam_normal",
            "bam_tumor",
            "OPTIONAL_FILE",
        ]
        for token in forbidden:
            with self.subTest(token=token):
                self.assertNotIn(token, somatic_entry)

    def test_somatic_tumour_only_sv_entry_does_not_launch_compatibility_graph_or_reports(self):
        main = read("main.nf")
        somatic_entry = main.split("workflow somatic_tumour_only_sv {", 1)[1].split(
            "// Compatibility entrypoint workflow", 1
        )[0]

        forbidden = [
            "ingress(",
            "prepare_reference(",
            "snp(",
            "sv(",
            "cnv_spectre(",
            "str(",
            "output_snp(",
            "combine_metrics_json(",
            "publish_artifact(",
            "makeReport",
            "bam_normal",
            "bam_tumor",
            "OPTIONAL_FILE",
        ]
        for token in forbidden:
            with self.subTest(token=token):
                self.assertNotIn(token, somatic_entry)

    def test_str_entry_does_not_launch_compatibility_graph_or_reports(self):
        main = read("main.nf")
        str_entry = main.split("workflow str {", 1)[1].split(
            "// Compatibility entrypoint workflow", 1
        )[0]

        forbidden = [
            "ingress(",
            "prepare_reference(",
            "snp(",
            "str_compat(",
            "output_str(",
            "output_snp(",
            "combine_metrics_json(",
            "publish_artifact(",
            "makeReport",
        ]
        for token in forbidden:
            with self.subTest(token=token):
                self.assertNotIn(token, str_entry)

    def test_methylation_entry_does_not_launch_compatibility_graph_or_reports(self):
        main = read("main.nf")
        methylation_entry = main.split("workflow methylation {", 1)[1].split(
            "// Compatibility entrypoint workflow", 1
        )[0]

        forbidden = [
            "ingress(",
            "prepare_reference(",
            "validate_modbam(",
            "sample_probs(",
            "mod(",
            "snp(",
            "output_snp(",
            "combine_metrics_json(",
            "publish_artifact(",
            "makeReport",
        ]
        for token in forbidden:
            with self.subTest(token=token):
                self.assertNotIn(token, methylation_entry)

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

    def test_somatic_germline_helper_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_somatic_germline_helper.nf")
        main = read("main.nf")

        for param in [
            "task_family",
            "task_key",
            "task_dir",
            "task_cache_dir",
            "completion_marker_path",
            "output_paths",
            "analysis_intent_id",
            "pair_id",
            "helper_sample_id",
            "helper_role",
            "helper_aggregate_xam",
            "helper_aggregate_xam_index",
            "helper_aggregate_xam_digest",
            "helper_aggregate_xam_index_digest",
            "reference_fasta",
            "reference_index",
            "reference_id",
            "reference_digest",
            "role_snapshot_digest",
            "relationship_snapshot_digest",
            "clair3_model",
            "clair3_model_digest",
            "clair3_model_table_digest",
            "germline_helper_config_digest",
            "container_digest",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"germline_helper_vcf"',
            '"germline_helper_vcf_index"',
            '"germline_helper_manifest"',
            '"germline_helper_command_json"',
            '"germline_helper_logs"',
            '"somatic_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn("workflow somatic_germline_helper {", main)
        self.assertIn("wf-human-variation.bounded_somatic_germline_helper.v1", helper)
        self.assertIn('"somatic_germline_helper"', helper)
        self.assertIn('"tumour"', helper)
        self.assertIn('"normal"', helper)
        self.assertIn('"control"', helper)
        self.assertIn("run_clair3.sh", module)
        self.assertIn('"helper_state": "computed"', module)
        self.assertIn('"normal_vcf_state": normal_vcf_state', module)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertNotIn("output_snp", module)
        self.assertNotIn("makeReport", module)

    def test_somatic_germline_helper_embedded_python_blocks_compile(self):
        module_path = "modules/local/bounded_somatic_germline_helper.nf"
        module = read(module_path)
        blocks = re.findall(r"python3 - <<'PY'\n(.*?)\nPY", module, flags=re.S)

        self.assertEqual(2, len(blocks))
        for index, block in enumerate(blocks, start=1):
            with self.subTest(block=index):
                compile(block, f"{module_path}:python-block-{index}", "exec")

    def test_somatic_phasing_and_haplotagging_entries_require_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_somatic_phasing.nf")
        main = read("main.nf")

        for param in [
            "analysis_intent_id",
            "pair_id",
            "sample_id",
            "sample_role",
            "reference_id",
            "role_snapshot_digest",
            "relationship_snapshot_digest",
            "input_vcf",
            "input_vcf_index",
            "input_vcf_digest",
            "input_vcf_index_digest",
            "somatic_phased_vcf",
            "somatic_phased_vcf_index",
            "somatic_phased_vcf_digest",
            "somatic_phased_vcf_index_digest",
            "role_aggregate_xam",
            "role_aggregate_xam_index",
            "role_aggregate_xam_digest",
            "role_aggregate_xam_index_digest",
            "reference_fasta",
            "reference_index",
            "reference_digest",
            "phasing_config_digest",
            "phasing_options_digest",
            "haplotagging_config_digest",
            "haplotagging_options_digest",
            "container_digest",
            "somatic_phasing_options",
            "somatic_haplotagging_options",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"selected_heterozygous_sites"',
            '"somatic_phased_vcf"',
            '"somatic_phased_vcf_index"',
            '"somatic_phasing_manifest"',
            '"somatic_phasing_command_json"',
            '"somatic_phasing_state"',
            '"somatic_haplotagged_xam"',
            '"somatic_haplotagged_xam_index"',
            '"somatic_haplotagged_contig_manifest"',
            '"somatic_haplotagging_manifest"',
            '"somatic_haplotagging_command_json"',
            '"somatic_haplotagging_state"',
            '"somatic_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn("workflow somatic_phasing {", main)
        self.assertIn("workflow somatic_haplotagging {", main)
        self.assertIn("wf-human-variation.bounded_somatic_phasing.v1", helper)
        self.assertIn("wf-human-variation.bounded_somatic_haplotagging.v1", helper)
        self.assertIn("unsupported somatic phasing option(s)", helper)
        self.assertIn("unsupported somatic haplotagging option(s)", helper)
        self.assertIn("bcftools", module)
        self.assertIn('"whatshap"', module)
        self.assertIn('"phase"', module)
        self.assertIn("whatshap haplotag", module)
        self.assertIn("selected_heterozygous_sites.vcf.gz", module)
        self.assertIn("somatic_phasing_state.v1", module)
        self.assertIn("somatic_haplotagging_state.v1", module)
        self.assertIn('"phasing_policy"', module)
        self.assertIn('"haplotagging_policy"', module)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertNotIn("haplotagphase", module)
        self.assertNotIn("makeReport", module)
        self.assertNotIn("params.phased", module)

    def test_somatic_phasing_embedded_python_blocks_compile(self):
        module_path = "modules/local/bounded_somatic_phasing.nf"
        module = read(module_path)
        blocks = re.findall(r"python3 - <<'PY'\n(.*?)\nPY", module, flags=re.S)

        self.assertEqual(2, len(blocks))
        for index, block in enumerate(blocks, start=1):
            with self.subTest(block=index):
                compile(block, f"{module_path}:python-block-{index}", "exec")

    def test_family_germline_snp_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_trio_candidate_selection.nf")

        for param in [
            "family_id",
            "analysis_intent_id",
            "reference_fasta",
            "reference_index",
            "reference_id",
            "role_snapshot_digest",
            "relationship_snapshot_digest",
            "proband_sample_id",
            "proband_snp_vcf",
            "proband_snp_vcf_index",
            "proband_snp_vcf_digest",
            "proband_snp_vcf_index_digest",
            "father_sample_id",
            "father_snp_vcf",
            "father_snp_vcf_index",
            "father_snp_vcf_digest",
            "father_snp_vcf_index_digest",
            "mother_sample_id",
            "mother_snp_vcf",
            "mother_snp_vcf_index",
            "mother_snp_vcf_digest",
            "mother_snp_vcf_index_digest",
            "clair3_nova_model",
            "clair3_nova_model_digest",
            "family_germline_config_digest",
            "container_digest",
            "family_germline_options",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"trio_candidate_manifest"',
            '"trio_candidate_beds"',
            '"trio_candidate_contigs"',
            '"trio_candidate_command_json"',
            '"family_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn("wf-human-variation.bounded_family_germline_snp.v1", helper)
        self.assertIn("unsupported family germline SNP option(s)", helper)
        self.assertIn("candidate_contigs", helper)
        self.assertIn("SelectCandidates_Trio", module)
        self.assertIn("--alt_fn_c", module)
        self.assertIn("--alt_fn_p1", module)
        self.assertIn("--alt_fn_p2", module)
        self.assertIn("--sampleName", module)
        self.assertIn('"trio_candidate_command.json"', module)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertIn('"input_vcf_kind": "snp_vcf"', module)
        self.assertIn("wf-trio used Clair3 pileup VCFs here", module)
        self.assertNotIn("proband_sample_name", module)
        self.assertNotIn("pat_sample_name", module)
        self.assertNotIn("mat_sample_name", module)
        self.assertNotIn("meta.alias", module)
        self.assertNotIn("makeReport", module)

    def test_family_germline_snp_denovo_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_trio_denovo_calling.nf")

        for param in [
            "family_id",
            "analysis_intent_id",
            "contig",
            "reference_fasta",
            "reference_index",
            "reference_id",
            "role_snapshot_digest",
            "relationship_snapshot_digest",
            "trio_candidate_beds",
            "trio_candidate_beds_digest",
            "proband_sample_id",
            "proband_bam",
            "proband_bam_index",
            "proband_bam_digest",
            "proband_bam_index_digest",
            "father_sample_id",
            "father_bam",
            "father_bam_index",
            "father_bam_digest",
            "father_bam_index_digest",
            "mother_sample_id",
            "mother_bam",
            "mother_bam_index",
            "mother_bam_digest",
            "mother_bam_index_digest",
            "clair3_nova_model",
            "clair3_nova_model_digest",
            "family_germline_config_digest",
            "container_digest",
            "family_germline_denovo_options",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"trio_denovo_manifest"',
            '"trio_denovo_vcf_fragments"',
            '"trio_denovo_state"',
            '"trio_denovo_command_json"',
            '"family_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn("wf-human-variation.bounded_family_germline_snp_denovo.v1", helper)
        self.assertIn("unsupported family germline SNP denovo option(s)", helper)
        self.assertIn("CallVarBam_Denovo", module)
        self.assertIn("--bam_fn_c", module)
        self.assertIn("--bam_fn_p1", module)
        self.assertIn("--bam_fn_p2", module)
        self.assertIn("--sampleName_c", module)
        self.assertIn("--sampleName_p1", module)
        self.assertIn("--sampleName_p2", module)
        self.assertIn("wf-human-variation.trio_denovo_state.v1", module)
        self.assertIn('"empty_candidate_region"', module)
        self.assertIn('"failed_candidate_region"', module)
        self.assertIn('"task_state": task_state', module)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertNotIn("proband_sample_name", module)
        self.assertNotIn("pat_sample_name", module)
        self.assertNotIn("mat_sample_name", module)
        self.assertNotIn("meta.alias", module)
        self.assertNotIn("makeReport", module)

    def test_family_germline_snp_merge_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_trio_merge_sort.nf")

        for param in [
            "family_id",
            "analysis_intent_id",
            "reference_fasta",
            "reference_index",
            "reference_id",
            "role_snapshot_digest",
            "relationship_snapshot_digest",
            "role",
            "sample_id",
            "trio_denovo_vcf_fragments",
            "trio_denovo_vcf_fragments_digest",
            "trio_candidate_beds",
            "trio_candidate_beds_digest",
            "snp_vcf",
            "snp_vcf_index",
            "snp_vcf_digest",
            "snp_vcf_index_digest",
            "snp_gvcf",
            "snp_gvcf_index",
            "snp_gvcf_digest",
            "snp_gvcf_index_digest",
            "clair3_nova_model_digest",
            "family_germline_config_digest",
            "container_digest",
            "family_germline_merge_options",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"trio_snp_vcf"',
            '"trio_snp_vcf_index"',
            '"trio_snp_gvcf"',
            '"trio_snp_gvcf_index"',
            '"trio_merge_manifest"',
            '"trio_merge_command_json"',
            '"family_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn("wf-human-variation.bounded_family_germline_snp_merge.v1", helper)
        self.assertIn("unsupported family germline SNP merge option(s)", helper)
        self.assertIn("SortVcf_Trio", module)
        self.assertIn("MergeVcf_Trio", module)
        self.assertIn("bcftools view", module)
        self.assertIn("bcftools annotate", module)
        self.assertIn("INFO/DNP", module)
        self.assertIn("FORMAT/DNP", module)
        self.assertIn('"tool_operations"', module)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertNotIn("proband_sample_name", module)
        self.assertNotIn("pat_sample_name", module)
        self.assertNotIn("mat_sample_name", module)
        self.assertNotIn("meta.alias", module)
        self.assertNotIn("makeReport", module)

    def test_family_joint_genotyping_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_family_joint_genotyping.nf")

        for param in [
            "family_id",
            "analysis_intent_id",
            "reference_fasta",
            "reference_index",
            "reference_digest",
            "reference_id",
            "role_snapshot_digest",
            "relationship_snapshot_digest",
            "pedigree_snapshot",
            "pedigree_snapshot_digest",
            "proband_sample_id",
            "proband_snp_gvcf",
            "proband_snp_gvcf_index",
            "proband_snp_gvcf_digest",
            "proband_snp_gvcf_index_digest",
            "father_sample_id",
            "father_snp_gvcf",
            "father_snp_gvcf_index",
            "father_snp_gvcf_digest",
            "father_snp_gvcf_index_digest",
            "mother_sample_id",
            "mother_snp_gvcf",
            "mother_snp_gvcf_index",
            "mother_snp_gvcf_digest",
            "mother_snp_gvcf_index_digest",
            "glnexus_config",
            "glnexus_config_digest",
            "container_digest",
            "family_joint_genotyping_options",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"family_joint_vcf"',
            '"family_joint_vcf_index"',
            '"family_joint_genotyping_manifest"',
            '"family_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn("wf-human-variation.bounded_family_joint_genotyping.v1", helper)
        self.assertIn("trio role sample ids must be distinct", helper)
        self.assertIn("sample_order", helper)
        self.assertIn("glnexus_cli", module)
        self.assertIn("gl_config.yml", module)
        self.assertIn("proband.gvcf.gz", module)
        self.assertIn("paternal.gvcf.gz", module)
        self.assertIn("maternal.gvcf.gz", module)
        self.assertIn("samples.lst", module)
        self.assertIn("pedigree snapshot does not match role sample ids", module)
        self.assertIn('"glnexus_config_digest"', module)
        self.assertIn('"reference_digest"', module)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertNotIn("proband_sample_name", module)
        self.assertNotIn("pat_sample_name", module)
        self.assertNotIn("mat_sample_name", module)
        self.assertNotIn("meta.alias", module)
        self.assertNotIn("makeReport", module)

    def test_family_pedigree_phasing_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_family_pedigree_phasing.nf")

        for param in [
            "family_id",
            "analysis_intent_id",
            "reference_fasta",
            "reference_index",
            "reference_digest",
            "reference_id",
            "role_snapshot_digest",
            "relationship_snapshot_digest",
            "pedigree_snapshot",
            "pedigree_snapshot_digest",
            "family_joint_vcf",
            "family_joint_vcf_index",
            "family_joint_vcf_digest",
            "family_joint_vcf_index_digest",
            "proband_sample_id",
            "proband_bam",
            "proband_bam_index",
            "father_sample_id",
            "father_bam",
            "father_bam_index",
            "mother_sample_id",
            "mother_bam",
            "mother_bam_index",
            "whatshap_config_digest",
            "container_digest",
            "family_pedigree_phasing_options",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"pedigree_filtered_vcf"',
            '"pedigree_filtered_vcf_index"',
            '"per_sample_phased_vcf_fragments"',
            '"pedigree_phasing_manifest"',
            '"pedigree_phasing_state"',
            '"family_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn("wf-human-variation.bounded_family_pedigree_phasing.v1", helper)
        self.assertIn("unsupported family pedigree phasing option(s)", helper)
        self.assertIn("whatshap", module)
        self.assertIn("--ped", module)
        self.assertIn("--only-snvs", module)
        self.assertIn("pedigree_phasing_state.v1", module)
        self.assertIn("skipped_disabled", module)
        self.assertIn("skipped_impossible_relationship_graph", module)
        self.assertIn("per_sample_phased_vcf_fragments", module)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertNotIn("proband_sample_name", module)
        self.assertNotIn("pat_sample_name", module)
        self.assertNotIn("mat_sample_name", module)
        self.assertNotIn("meta.alias", module)
        self.assertNotIn("makeReport", module)

    def test_family_haplotagging_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_family_haplotagging.nf")

        for param in [
            "family_id",
            "analysis_intent_id",
            "reference_fasta",
            "reference_index",
            "reference_digest",
            "reference_id",
            "role_snapshot_digest",
            "relationship_snapshot_digest",
            "pedigree_filtered_vcf",
            "pedigree_filtered_vcf_index",
            "pedigree_filtered_vcf_digest",
            "pedigree_filtered_vcf_index_digest",
            "proband_sample_id",
            "proband_xam",
            "proband_xam_index",
            "father_sample_id",
            "father_xam",
            "father_xam_index",
            "mother_sample_id",
            "mother_xam",
            "mother_xam_index",
            "whatshap_config_digest",
            "container_digest",
            "family_haplotagging_options",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"family_haplotagged_alignments"',
            '"family_haplotagged_contig_manifest"',
            '"family_haplotagging_manifest"',
            '"family_haplotagging_state"',
            '"family_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn("wf-human-variation.bounded_family_haplotagging.v1", helper)
        self.assertIn("unsupported family haplotagging option(s)", helper)
        self.assertIn("whatshap haplotag", module)
        self.assertIn("--ignore-read-groups", module)
        self.assertIn("family_haplotagging_state.v1", module)
        self.assertIn("skipped_disabled", module)
        self.assertIn("family_haplotagged_contig_manifest.v1", module)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertNotIn("proband_sample_name", module)
        self.assertNotIn("pat_sample_name", module)
        self.assertNotIn("mat_sample_name", module)
        self.assertNotIn("meta.alias", module)
        self.assertNotIn("makeReport", module)
        self.assertNotIn("haplotagphase", module)

    def test_family_sv_calling_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_family_sv_calling.nf")
        main = read("main.nf")

        for param in [
            "family_id",
            "analysis_intent_id",
            "role",
            "sample_id",
            "reference_fasta",
            "reference_index",
            "reference_digest",
            "reference_id",
            "role_snapshot_digest",
            "relationship_snapshot_digest",
            "aggregate_xam",
            "aggregate_xam_index",
            "aggregate_xam_digest",
            "aggregate_xam_index_digest",
            "mosdepth_summary",
            "mosdepth_summary_digest",
            "target_bed",
            "target_bed_digest",
            "sniffles_config_digest",
            "container_digest",
            "structural_variant_options",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"structural_variant_vcf"',
            '"structural_variant_vcf_index"',
            '"structural_variant_snf"',
            '"family_sv_calling_command_json"',
            '"family_sv_calling_manifest"',
            '"family_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn("wf-human-variation.bounded_family_sv_calling.v1", helper)
        self.assertIn("role", helper)
        self.assertIn("sniffles", module)
        self.assertIn("--snf", module)
        self.assertIn("structural_variant.snf", module)
        self.assertIn("family_sv_calling_manifest.v1", module)
        self.assertIn("family_sv_calling_command.json", module)
        self.assertIn('"tool": "sniffles2"', module)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertIn("workflow family_sv_calling {", main)
        self.assertNotIn("meta.alias", module)
        self.assertNotIn("makeReport", module)
        self.assertNotIn("--phase", module)
        self.assertNotIn("groupTuple", module)

    def test_family_sv_merging_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_family_sv_merging.nf")
        main = read("main.nf")

        for param in [
            "family_id",
            "analysis_intent_id",
            "reference_fasta",
            "reference_index",
            "reference_digest",
            "reference_id",
            "role_snapshot_digest",
            "relationship_snapshot_digest",
            "target_bed",
            "target_bed_digest",
            "sniffles_config_digest",
            "container_digest",
            "family_sv_merging_options",
            "proband_snf",
            "proband_snf_digest",
            "proband_snf_reference_digest",
            "father_snf",
            "mother_snf",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"family_sv_vcf"',
            '"family_sv_vcf_index"',
            '"family_sv_merging_command_json"',
            '"family_sv_merging_manifest"',
            '"family_sv_merging_state"',
            '"family_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn("wf-human-variation.bounded_family_sv_merging.v1", helper)
        self.assertIn("unsupported family SV merging option(s)", helper)
        self.assertIn("allow_subset", helper)
        self.assertIn("sniffles", module)
        self.assertIn("--input", module)
        self.assertIn("family_sv_merging_state.v1", module)
        self.assertIn("family_sv_merging_manifest.v1", module)
        self.assertIn("family_sv_merging_command.json", module)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertIn("workflow family_sv_merging {", main)
        self.assertNotIn("meta.alias", module)
        self.assertNotIn("makeReport", module)
        self.assertNotIn("--phase", module)
        self.assertNotIn("groupTuple", module)

    def test_family_mendelian_assessment_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_family_mendelian_assessment.nf")
        main = read("main.nf")

        for param in [
            "family_id",
            "analysis_intent_id",
            "reference_sdf",
            "reference_digest",
            "reference_id",
            "pedigree_snapshot",
            "pedigree_snapshot_digest",
            "role_snapshot_digest",
            "relationship_snapshot_digest",
            "rtg_config_digest",
            "container_digest",
            "family_mendelian_assessment_options",
            "family_joint_vcf",
            "family_joint_vcf_digest",
            "family_sv_vcf",
            "family_sv_vcf_digest",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"family_rtg_snp_summary"',
            '"family_rtg_sv_summary"',
            '"mendelian_summary"',
            '"mendelian_metrics"',
            '"family_mendelian_assessment_manifest"',
            '"family_mendelian_assessment_state"',
            '"family_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn("wf-human-variation.bounded_family_mendelian_assessment.v1", helper)
        self.assertIn("unsupported family Mendelian assessment option(s)", helper)
        self.assertIn("allow_subset", helper)
        self.assertIn("rtg", module)
        self.assertIn("rtg_mendelian", module)
        self.assertIn("family.ped", module)
        self.assertIn("family_mendelian_assessment_manifest.v1", module)
        self.assertIn("family_mendelian_assessment_state.v1", module)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertIn("workflow family_mendelian_assessment {", main)
        self.assertNotIn("makeReport", module)
        self.assertNotIn("publishDir", module)
        self.assertNotIn("text/html", module)
        self.assertNotIn("groupTuple", module)

    def test_somatic_tumour_only_snv_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_somatic_tumour_only_snv.nf")
        main = read("main.nf")
        families = read("lib/task_families.nf")

        for param in [
            "analysis_intent_id",
            "role_snapshot_digest",
            "aggregate_xam",
            "aggregate_xam_index",
            "aggregate_xam_digest",
            "aggregate_xam_index_digest",
            "reference_fasta",
            "reference_index",
            "reference_digest",
            "clairs_to_model",
            "clairs_to_model_digest",
            "clairs_to_model_table_digest",
            "clairs_to_database_bundle",
            "clairs_to_database_bundle_digest",
            "clairs_to_config_digest",
            "clairs_to_options_digest",
            "container_digest",
            "target_bed",
            "candidate_vcf",
            "genotyping_vcf",
            "clairs_to_options",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"somatic_snv_vcf"',
            '"somatic_snv_vcf_index"',
            '"somatic_tumour_only_snv_manifest"',
            '"somatic_tumour_only_snv_command_json"',
            '"somatic_tumour_only_snv_logs"',
            '"somatic_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn('"somatic_tumour_only_snv"', families)
        self.assertIn("wf-human-variation.bounded_somatic_tumour_only_snv.v1", helper)
        self.assertIn("unsupported ClairS-TO option(s)", helper)
        self.assertIn("run_clairs_to", module)
        self.assertIn("--tumor_bam_fn", module)
        self.assertIn("--ref_fn", module)
        self.assertIn("--platform", module)
        self.assertIn("--snv_min_af", module)
        self.assertIn("--hybrid_mode_vcf_fn", module)
        self.assertIn("--genotyping_mode_vcf_fn", module)
        self.assertIn(".wf-somatic-snv.vcf.gz", module)
        self.assertIn("somatic_tumour_only_snv_manifest.v1", module)
        self.assertIn("somatic_tumour_only_snv_command.v1", module)
        self.assertIn('"clairs_to_options_digest"', module)
        self.assertIn('"clairs_to_options": contract["clairs_to_options_digest"]', module)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertIn("workflow somatic_tumour_only_snv {", main)
        self.assertNotIn("makeReport", module)
        self.assertNotIn("publishDir", module)
        self.assertNotIn("text/html", module)
        self.assertNotIn("bam_normal", module)
        self.assertNotIn("OPTIONAL_FILE", module)
        self.assertNotIn("groupTuple", module)

    def test_somatic_tumour_only_sv_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_somatic_tumour_only_sv.nf")
        main = read("main.nf")
        families = read("lib/task_families.nf")

        for param in [
            "analysis_intent_id",
            "role_snapshot_digest",
            "aggregate_xam",
            "aggregate_xam_index",
            "aggregate_xam_kind",
            "aggregate_xam_digest",
            "aggregate_xam_index_digest",
            "reference_fasta",
            "reference_index",
            "reference_digest",
            "reference_genome_build",
            "pon_file",
            "pon_file_digest",
            "trf_bed",
            "trf_bed_digest",
            "severus_config_digest",
            "severus_options_digest",
            "container_digest",
            "severus_options",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"somatic_sv_vcf"',
            '"somatic_sv_vcf_index"',
            '"somatic_sv_raw_directory"',
            '"somatic_tumour_only_sv_manifest"',
            '"somatic_tumour_only_sv_command_json"',
            '"somatic_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn('"somatic_tumour_only_sv"', families)
        self.assertIn("wf-human-variation.bounded_somatic_tumour_only_sv.v1", helper)
        self.assertIn("unsupported Severus option(s)", helper)
        self.assertIn("severus", module)
        self.assertIn("--target-bam", module)
        self.assertIn("--out-dir", module)
        self.assertIn("--PON", module)
        self.assertIn("--vntr-bed", module)
        self.assertIn("--single-bp", module)
        self.assertIn("--resolve-overlaps", module)
        self.assertIn("--between-junction-ins", module)
        self.assertIn(".wf-somatic-sv.vcf.gz", module)
        self.assertIn("somatic_tumour_only_sv_manifest.v1", module)
        self.assertIn("somatic_tumour_only_sv_command.v1", module)
        self.assertIn('"severus_options_digest"', module)
        self.assertIn('"severus_options": contract["severus_options_digest"]', module)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertIn("workflow somatic_tumour_only_sv {", main)
        self.assertIn("entry_contract.pon_file ? Channel.fromPath(entry_contract.pon_file", main)
        self.assertIn("entry_contract.trf_bed ? Channel.fromPath(entry_contract.trf_bed", main)
        self.assertIn("STAGED_PON_FILE", module)
        self.assertIn("STAGED_TRF_BED", module)
        self.assertNotIn("makeReport", module)
        self.assertNotIn("publishDir", module)
        self.assertNotIn("text/html", module)
        self.assertNotIn("bam_normal", module)
        self.assertNotIn("OPTIONAL_FILE", module)
        self.assertNotIn("groupTuple", module)

    def test_somatic_paired_snv_candidate_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_somatic_paired_snv.nf")
        main = read("main.nf")
        families = read("lib/task_families.nf")

        for param in [
            "analysis_intent_id",
            "pair_id",
            "region_id",
            "contig",
            "role_snapshot_digest",
            "relationship_snapshot_digest",
            "tumour_aggregate_xam",
            "normal_or_control_aggregate_xam",
            "normal_vcf",
            "shared_region_bed",
            "reference_fasta",
            "clairs_model",
            "clairs_reference_bundle",
            "clairs_config_digest",
            "clairs_options",
            "clairs_options_digest",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"somatic_candidate_snv"',
            '"somatic_candidate_indel"',
            '"somatic_candidate_hybrid"',
            '"somatic_candidate_bed"',
            '"somatic_paired_snv_candidate_manifest"',
            '"somatic_paired_snv_candidate_command_json"',
            '"somatic_paired_snv_candidate_logs"',
            '"somatic_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn('"somatic_paired_snv"', families)
        self.assertIn("paired_candidate_extraction", families)
        self.assertIn("wf-human-variation.bounded_somatic_paired_snv_candidate.v1", helper)
        self.assertIn("unsupported ClairS option(s)", helper)
        self.assertIn("extract_pair_candidates", module)
        self.assertIn("--tumor_bam_fn", module)
        self.assertIn("--normal_bam_fn", module)
        self.assertIn("--candidates_folder", module)
        self.assertIn("somatic_paired_snv_candidate_manifest.v1", module)
        self.assertIn("somatic_paired_snv_candidate_command.v1", module)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertIn("workflow somatic_paired_snv_candidate {", main)
        self.assertNotIn("makeReport", module)
        self.assertNotIn("publishDir", module)
        self.assertNotIn("text/html", module)
        self.assertNotIn("OPTIONAL_FILE", module)
        self.assertNotIn("groupTuple", module)

    def test_somatic_paired_snv_pileup_entry_requires_chunk_scoped_inputs(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_somatic_paired_snv.nf")
        main = read("main.nf")
        families = read("lib/task_families.nf")

        for param in [
            "region_id",
            "contig",
            "variant_type",
            "candidate_bed",
            "candidate_bed_digest",
            "candidate_variants",
            "candidate_variants_digest",
            "clairs_model",
            "clairs_model_table_digest",
            "clairs_options_digest",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"somatic_pileup_prediction_fragments"',
            '"somatic_pileup_prediction_manifest"',
            '"somatic_pileup_prediction_command_json"',
            '"somatic_paired_snv_pileup_logs"',
            '"somatic_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn("paired_pileup_tensor_prediction", families)
        self.assertIn("wf-human-variation.bounded_somatic_paired_snv_pileup.v1", helper)
        self.assertIn("create_pair_tensor_pileup", module)
        self.assertIn("--candidates_bed_regions", module)
        self.assertIn("--tensor_can_fn", module)
        self.assertIn('"predict": predict', module)
        self.assertIn("somatic_pileup_prediction_manifest.v1", module)
        self.assertIn("workflow somatic_paired_snv_pileup {", main)
        self.assertIn('"variant_type": contract["variant_type"]', module)
        self.assertNotIn("WFSV_PON_PATH", module)
        self.assertNotIn("WFSV_TRBED_PATH", module)

    def test_somatic_paired_snv_full_alignment_entry_requires_chunk_scoped_inputs(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_somatic_paired_snv.nf")
        main = read("main.nf")
        families = read("lib/task_families.nf")

        for param in [
            "region_id",
            "contig",
            "variant_type",
            "alignment_state",
            "tumour_alignment_xam",
            "tumour_alignment_xam_digest",
            "normal_or_control_alignment_xam",
            "normal_or_control_alignment_xam_digest",
            "candidate_bed",
            "candidate_bed_digest",
            "candidate_variants",
            "candidate_variants_digest",
            "clairs_model",
            "clairs_model_table_digest",
            "clairs_options_digest",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"somatic_full_alignment_prediction_fragments"',
            '"somatic_full_alignment_prediction_manifest"',
            '"somatic_full_alignment_prediction_command_json"',
            '"somatic_paired_snv_full_alignment_logs"',
            '"somatic_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn("paired_full_alignment_tensor_prediction", families)
        self.assertIn("wf-human-variation.bounded_somatic_paired_snv_full_alignment.v1", helper)
        self.assertIn("create_pair_tensor", module)
        self.assertIn("--candidates_bed_regions", module)
        self.assertIn("--tensor_can_fn", module)
        self.assertIn("full_alignment.pkl", module)
        self.assertIn("somatic_full_alignment_prediction_manifest.v1", module)
        self.assertIn("workflow somatic_paired_snv_full_alignment {", main)
        self.assertIn('"alignment_state": contract["alignment_state"]', module)
        self.assertNotIn("WFSV_PON_PATH", module)
        self.assertNotIn("WFSV_TRBED_PATH", module)

    def test_somatic_paired_snv_merge_entry_produces_final_vcf(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_somatic_paired_snv.nf")
        main = read("main.nf")
        families = read("lib/task_families.nf")

        for param in [
            "variant_type",
            "pileup_prediction_fragments",
            "pileup_prediction_fragments_digest",
            "full_alignment_prediction_fragments",
            "full_alignment_prediction_fragments_digest",
            "contigs_file",
            "contigs_file_digest",
            "reference_fasta",
            "reference_digest",
            "clairs_config_digest",
            "clairs_options_digest",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"somatic_snv_vcf"',
            '"somatic_snv_vcf_index"',
            '"somatic_paired_snv_manifest"',
            '"somatic_paired_snv_command_json"',
            '"somatic_paired_snv_logs"',
            '"somatic_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn("paired_final_vcf_merge", families)
        self.assertIn("wf-human-variation.bounded_somatic_paired_snv_merge.v1", helper)
        self.assertIn("sort_vcf", module)
        self.assertIn("merge_vcf", module)
        self.assertIn("--pileup_vcf_fn", module)
        self.assertIn("--full_alignment_vcf_fn", module)
        self.assertIn("--qual", module)
        self.assertIn("somatic_paired_snv_manifest.v1", module)
        self.assertIn("workflow somatic_paired_snv_merge {", main)
        self.assertNotIn("makeReport", module)
        self.assertNotIn("publishDir", module)

    def test_somatic_paired_snv_embedded_python_blocks_compile(self):
        module_path = "modules/local/bounded_somatic_paired_snv.nf"
        module = read(module_path)
        blocks = re.findall(r"python3 - <<'PY'\n(.*?)\nPY", module, flags=re.S)

        self.assertEqual(8, len(blocks))
        for index, block in enumerate(blocks, start=1):
            with self.subTest(block=index):
                compile(block, f"{module_path}:python-block-{index}", "exec")

    def test_somatic_qc_entry_materialises_shared_callable_regions(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_somatic_qc.nf")
        main = read("main.nf")
        families = read("lib/task_families.nf")

        for param in [
            "analysis_intent_id",
            "pair_id",
            "tumour_sample_id",
            "normal_or_control_sample_id",
            "normal_or_control_role",
            "reference_id",
            "reference_genome_build",
            "role_snapshot_digest",
            "relationship_snapshot_digest",
            "tumour_mosdepth_regions",
            "tumour_mosdepth_regions_digest",
            "normal_or_control_mosdepth_regions",
            "normal_or_control_mosdepth_regions_digest",
            "target_bed",
            "target_bed_digest",
            "coverage_thresholds_digest",
            "somatic_qc_config_digest",
            "container_digest",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"somatic_shared_regions_bed"',
            '"somatic_rejected_regions_summary"',
            '"somatic_qc_manifest"',
            '"somatic_qc_metrics"',
            '"somatic_provenance"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn('"somatic_qc"', families)
        self.assertIn("somatic_shared_region_projection", families)
        self.assertIn("wf-human-variation.bounded_somatic_qc.v1", helper)
        self.assertIn("workflow somatic_qc {", main)
        self.assertIn("runBoundedSomaticQcTask(", main)
        self.assertIn("somatic_qc_manifest.v1", module)
        self.assertIn("somatic_qc_metrics.v1", module)
        self.assertIn("shared_callable_regions_bed", module)
        self.assertIn("shared_region_empty", module)
        self.assertIn('sizes["shared_callable_bp"] == 0', module)
        self.assertIn("somatic_rejected_regions_summary.tsv", module)
        self.assertIn("target_bed_excluded", module)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertNotIn("get_shared_region", module)
        self.assertNotIn("makeReport", module)
        self.assertNotIn("publishDir", module)
        self.assertNotIn("text/html", module)
        self.assertNotIn("groupTuple", module)
        self.assertNotIn("OPTIONAL_FILE", module)
        self.assertNotIn("PoN_1000G", module)
        self.assertNotIn("hg38.segdups", module)
        self.assertNotIn("seg_dup.bed", module)
        self.assertNotIn("SEG_DUP", module)

    def test_somatic_tumour_only_sv_embedded_python_blocks_compile(self):
        module_path = "modules/local/bounded_somatic_tumour_only_sv.nf"
        module = read(module_path)
        blocks = re.findall(r"python3 - <<'PY'\n(.*?)\nPY", module, flags=re.S)

        self.assertEqual(2, len(blocks))
        for index, block in enumerate(blocks, start=1):
            with self.subTest(block=index):
                compile(block, f"{module_path}:python-block-{index}", "exec")

    def test_somatic_qc_embedded_python_blocks_compile(self):
        module_path = "modules/local/bounded_somatic_qc.nf"
        module = read(module_path)
        blocks = re.findall(r"python3 - <<'PY'\n(.*?)\nPY", module, flags=re.S)

        self.assertEqual(1, len(blocks))
        compile(blocks[0], f"{module_path}:python-block-1", "exec")

    def test_somatic_annotation_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_somatic_annotation.nf")
        main = read("main.nf")
        families = read("lib/task_families.nf")

        for param in [
            "analysis_intent_id",
            "role_snapshot_digest",
            "source_output_artefact_id",
            "annotation_mode",
            "reference_id",
            "reference_genome_build",
            "source_vcf",
            "source_vcf_index",
            "source_vcf_digest",
            "source_vcf_index_digest",
            "snpeff_database",
            "snpeff_database_name",
            "snpeff_database_digest",
            "clinvar_vcf",
            "clinvar_vcf_index",
            "clinvar_vcf_digest",
            "sift_annotation",
            "sift_annotation_digest",
            "annotation_config_digest",
            "container_digest",
            "somatic_annotation_options",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"somatic_annotated_vcf"',
            '"somatic_annotated_vcf_index"',
            '"somatic_clinvar_vcf"',
            '"somatic_clinvar_vcf_index"',
            '"somatic_annotation_manifest"',
            '"somatic_annotation_command_json"',
            '"somatic_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn('"somatic_annotation"', families)
        self.assertIn("wf-human-variation.bounded_somatic_annotation.v1", helper)
        self.assertIn("unsupported somatic annotation option(s)", helper)
        self.assertIn("workflow somatic_annotation {", main)
        self.assertIn("snpEff", module)
        self.assertIn("SnpSift", module)
        self.assertIn("-dataDir", module)
        self.assertIn("somatic_annotation_manifest.v1", module)
        self.assertIn("somatic_annotation_command.v1", module)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertIn("entry_contract.clinvar_vcf ? Channel.fromPath(entry_contract.clinvar_vcf", main)
        self.assertIn("entry_contract.sift_annotation ? Channel.fromPath(entry_contract.sift_annotation", main)
        self.assertNotIn("publishDir", module)
        self.assertNotIn("makeReport", module)
        self.assertNotIn("text/html", module)
        self.assertNotIn("CLINVAR_PATH", module)
        self.assertNotIn("getGenome", module)
        self.assertNotIn("SEG_DUP", module)
        self.assertNotIn("hg38.segdups", module)

    def test_somatic_annotation_embedded_python_blocks_compile(self):
        module_path = "modules/local/bounded_somatic_annotation.nf"
        module = read(module_path)
        blocks = re.findall(r"python3 - <<'PY'\n(.*?)\nPY", module, flags=re.S)

        self.assertEqual(2, len(blocks))
        for index, block in enumerate(blocks, start=1):
            with self.subTest(block=index):
                compile(block, f"{module_path}:python-block-{index}", "exec")

    def test_somatic_methylation_aggregation_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_somatic_methylation_aggregation.nf")
        main = read("main.nf")
        families = read("lib/task_families.nf")

        for param in [
            "analysis_intent_id",
            "sample_id",
            "sample_role",
            "role_snapshot_digest",
            "reference_id",
            "reference_genome_build",
            "role_aggregate_xam",
            "role_aggregate_xam_index",
            "role_aggregate_xam_digest",
            "role_aggregate_xam_index_digest",
            "reference_fasta",
            "reference_index",
            "modkit_config_digest",
            "somatic_methylation_options_digest",
            "container_digest",
            "somatic_methylation_options",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"somatic_bedmethyl"',
            '"somatic_bedmethyl_index"',
            '"somatic_bigwig"',
            '"somatic_mod_summary"',
            '"somatic_dss_input_tsv"',
            '"somatic_methylation_aggregation_manifest"',
            '"somatic_methylation_aggregation_command_json"',
            '"somatic_methylation_aggregation_log"',
            '"somatic_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn('"somatic_methylation_aggregation"', families)
        self.assertIn("modkit_role_aggregation", families)
        self.assertIn("wf-human-variation.bounded_somatic_methylation_aggregation.v1", helper)
        self.assertIn("workflow somatic_methylation_aggregation {", main)
        self.assertIn("workflow-glue check_valid_modbam", module)
        self.assertIn("modkit sample-probs", module)
        self.assertIn("modkit pileup", module)
        self.assertIn("modkit summary", module)
        self.assertIn("modkit bm tobigwig", module)
        self.assertIn("somatic_methylation_aggregation_manifest.v1", module)
        self.assertIn("somatic_methylation_aggregation_command.v1", module)
        self.assertIn('"somatic_methylation_options_digest"', module)
        self.assertIn('"somatic_methylation_options": contract["somatic_methylation_options_digest"]', module)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertIn('"html_report": {"requested": False', module)
        self.assertIn('"dss": {"requested": False', module)
        for forbidden in [
            "makeModReport",
            "workflow-glue report_mod",
            "LabsReport",
            "DMLtest",
            "callDML",
            "callDMR",
            "library(DSS)",
            "publishDir",
            "OPTIONAL_FILE",
            "params.bam_normal",
            "params.modkit_args",
            "dss_threads",
            "Pinguscript",
            "igv",
        ]:
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, module)

    def test_somatic_methylation_aggregation_embedded_python_blocks_compile(self):
        module_path = "modules/local/bounded_somatic_methylation_aggregation.nf"
        module = read(module_path)
        blocks = re.findall(r"python3 - <<'PY'\n(.*?)\nPY", module, flags=re.S)

        self.assertEqual(2, len(blocks))
        for index, block in enumerate(blocks, start=1):
            with self.subTest(block=index):
                compile(block, f"{module_path}:python-block-{index}", "exec")

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

    def test_cnv_entry_requires_mode_specific_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_cnv.nf")
        main = read("main.nf")

        for param in [
            "cnv_mode",
            "aggregate_xam",
            "aggregate_xam_index",
            "aggregate_xam_kind",
            "aggregate_xam_digest",
            "reference_fasta",
            "reference_index",
            "reference_id",
            "cnv_config_digest",
            "container_digest",
            "cnv_options",
            "qdnaseq_options",
            "snp_vcf",
            "snp_vcf_index",
            "snp_vcf_digest",
            "mosdepth_summary",
            "mosdepth_regions",
            "mosdepth_distribution",
            "mosdepth_thresholds",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"cnv_vcf"',
            '"cnv_vcf_index"',
            '"cnv_bed"',
            '"cnv_karyotype"',
            '"cnv_segments_bed"',
            '"cnv_segments_vcf"',
            '"cnv_manifest"',
            '"cnv_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn('if (entry_contract.cnv_mode == "spectre")', main)
        self.assertIn("wf-human-variation.bounded_cnv.v1", helper)
        self.assertIn('"spectre"', helper)
        self.assertIn('"qdnaseq"', helper)
        self.assertIn("cnv_mode 'qdnaseq' requires aggregate_xam_kind=bam", helper)
        self.assertIn("unsupported CNV option(s)", helper)
        self.assertIn("unsupported Spectre option(s)", helper)
        self.assertIn("unsupported QDNAseq option(s)", helper)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertIn('"spectre", "CNVCaller"', module)
        self.assertIn("run_qdnaseq.r", module)
        self.assertIn("fix_qdnaseq_vcf.py", module)
        self.assertIn('"tool": "spectre"', module)
        self.assertIn('"tool": "qdnaseq"', module)
        self.assertIn('"html_report": {"requested": False', module)
        self.assertNotIn("output_cnv", module)
        self.assertNotIn("makeReport", module)

    def test_str_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_str.nf")

        for param in [
            "task_family",
            "task_key",
            "task_dir",
            "task_cache_dir",
            "completion_marker_path",
            "output_paths",
            "sample_id",
            "reference_id",
            "haplotagged_contig_manifest",
            "haplotagged_contig_digest",
            "reference_fasta",
            "reference_index",
            "sex",
            "repeat_bed",
            "variant_catalogue",
            "str_config_digest",
            "container_digest",
            "str_options",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"str_vcf"',
            '"str_vcf_index"',
            '"str_loci_tsv"',
            '"straglr_tsv"',
            '"stranger_tsv"',
            '"str_content_csv"',
            '"str_manifest"',
            '"str_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)

        self.assertIn("wf-human-variation.bounded_str.v1", helper)
        self.assertIn("unsupported STR option(s)", helper)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertIn("straglr-genotype", module)
        self.assertIn("stranger -f", module)
        self.assertIn("workflow-glue generate_str_content", module)
        self.assertIn('"html_report": {"requested": False', module)
        self.assertIn("haplotagged contig manifest must contain a non-empty contig list", module)
        self.assertNotIn("output_str", module)
        self.assertNotIn("makeReport", module)

    def test_methylation_entry_requires_controller_owned_task_params(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_methylation.nf")

        for param in [
            "task_family",
            "task_key",
            "task_dir",
            "task_cache_dir",
            "completion_marker_path",
            "output_paths",
            "sample_id",
            "reference_id",
            "methylation_mode",
            "aggregate_xam",
            "aggregate_xam_index",
            "aggregate_xam_digest",
            "haplotagged_xam",
            "haplotagged_xam_index",
            "haplotagged_xam_digest",
            "reference_fasta",
            "reference_index",
            "methylation_config_digest",
            "container_digest",
            "methylation_options",
        ]:
            with self.subTest(param=param):
                self.assertIn(param, helper)

        for output in [
            '"bedmethyl"',
            '"bigwig"',
            '"methylation_manifest"',
            '"methylation_provenance"',
            '"qc_stats"',
        ]:
            with self.subTest(output=output):
                self.assertIn(output, helper)
        for optional_output in [
            "bedmethyl_hap1",
            "bedmethyl_hap2",
            "bigwig_hap1",
            "bigwig_hap2",
        ]:
            with self.subTest(optional_output=optional_output):
                self.assertIn(optional_output, module)

        self.assertIn("wf-human-variation.bounded_methylation.v1", helper)
        self.assertIn('"unphased"', helper)
        self.assertIn('"phased"', helper)
        self.assertIn("block_or_controller_degrade_to_unphased", helper)
        self.assertIn("unsupported methylation option(s)", helper)
        self.assertIn('"marker_schema": "gnostikon.task_completion.v1"', module)
        self.assertIn("workflow-glue check_valid_modbam", module)
        self.assertIn("modkit sample-probs", module)
        self.assertIn("modkit pileup", module)
        self.assertIn("modkit bm tobigwig", module)
        self.assertIn('"html_report": {"requested": False', module)
        self.assertNotIn("makeReport", module)
        self.assertNotIn("publishDir", module)

    def test_bounded_entry_surfaces_do_not_use_global_join_barriers(self):
        main = read("main.nf")
        bounded_surface = main.split("// Compatibility entrypoint workflow", 1)[0]
        bounded_modules = "\n".join(
            read(path)
            for path in [
                "modules/local/bounded_mapping.nf",
                "modules/local/bounded_sample_aggregation.nf",
                "modules/local/bounded_variant_calling.nf",
                "modules/local/bounded_somatic_germline_helper.nf",
                "modules/local/bounded_somatic_phasing.nf",
                "modules/local/bounded_structural_variant_calling.nf",
                "modules/local/bounded_trio_candidate_selection.nf",
                "modules/local/bounded_trio_denovo_calling.nf",
                "modules/local/bounded_trio_merge_sort.nf",
                "modules/local/bounded_family_joint_genotyping.nf",
                "modules/local/bounded_family_pedigree_phasing.nf",
                "modules/local/bounded_family_haplotagging.nf",
                "modules/local/bounded_family_sv_calling.nf",
                "modules/local/bounded_family_sv_merging.nf",
                "modules/local/bounded_family_mendelian_assessment.nf",
                "modules/local/bounded_somatic_tumour_only_snv.nf",
                "modules/local/bounded_somatic_germline_helper.nf",
                "modules/local/bounded_somatic_phasing.nf",
                "modules/local/bounded_somatic_paired_snv.nf",
                "modules/local/bounded_somatic_qc.nf",
                "modules/local/bounded_somatic_tumour_only_sv.nf",
                "modules/local/bounded_somatic_annotation.nf",
                "modules/local/bounded_somatic_methylation_aggregation.nf",
                "modules/local/bounded_cnv.nf",
                "modules/local/bounded_str.nf",
                "modules/local/bounded_methylation.nf",
            ]
        )

        forbidden = [
            ".collect(",
            ".combine(",
            ".first(",
            "groupTuple(",
        ]
        for token in forbidden:
            with self.subTest(token=token):
                self.assertNotIn(token, bounded_surface)
                self.assertNotIn(token, bounded_modules)

    def test_bounded_somatic_entries_reject_inherited_free_form_tool_arguments(self):
        bounded_somatic_code = "\n".join(
            read(path)
            for path in [
                "lib/bounded_entry.nf",
                "modules/local/bounded_somatic_tumour_only_snv.nf",
                "modules/local/bounded_somatic_qc.nf",
                "modules/local/bounded_somatic_tumour_only_sv.nf",
                "modules/local/bounded_somatic_methylation_aggregation.nf",
            ]
        )

        for token in [
            "params.severus_args",
            "params.modkit_args",
            "severus_args",
            "modkit_args",
            "clairs_args",
            "clairs_to_args",
            "dss_args",
            "params.r_args",
            "phasing_args",
            "longphase_args",
            "whatshap_args",
            "task.ext.args",
            "ext.args",
            "library(DSS)",
            "DMLtest",
            "callDML",
            "callDMR",
            "dss_threads",
        ]:
            with self.subTest(token=token):
                self.assertNotIn(token, bounded_somatic_code)

        for token in [
            "unsupported ClairS-TO option(s)",
            "unsupported Severus option(s)",
            "unsupported methylation option(s)",
            "clairs_to_options",
            "clairs_to_options_digest",
            "severus_options",
            "severus_options_digest",
            "somatic_methylation_options",
            "somatic_methylation_options_digest",
            "structured_options",
        ]:
            with self.subTest(token=token):
                self.assertIn(token, bounded_somatic_code)

    def test_remaining_broad_joins_are_documented_as_compatibility_debt(self):
        docs = read("docs/keyed-joins.rst")

        self.assertIn("Task 22 Barrier Inventory", docs)
        self.assertIn("compatibility-only debt", docs)
        for owner in [
            "variant_calling",
            "str",
            "methylation",
            "cnv",
            "reporting",
        ]:
            with self.subTest(owner=owner):
                self.assertIn(owner, docs)
        for path in [
            "main.nf",
            "workflows/wf-human-snp.nf",
            "workflows/wf-human-str.nf",
            "workflows/methyl.nf",
            "workflows/wf-human-cnv.nf",
            "workflows/partners.nf",
        ]:
            with self.subTest(path=path):
                self.assertIn(f"``{path}``", docs)

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
                "docs/family-analysis.rst",
                "docs/somatic-import-baseline.rst",
                "docs/explicit-prerequisites.rst",
                "docs/outputs.rst",
                "docs/maintenance.rst",
                "docs/testing.rst",
            ]
        )
        ledger = read("docs/maintenance.rst") + "\n" + read("docs/controller-execution.rst")

        self.assertIn("``-entry mapping``", docs)
        self.assertIn("``-entry sample_aggregation``", docs)
        self.assertIn("``-entry variant_calling``", docs)
        self.assertIn("``-entry somatic_germline_helper``", docs)
        self.assertIn("``-entry somatic_phasing``", docs)
        self.assertIn("``-entry somatic_haplotagging``", docs)
        self.assertIn("``-entry cnv``", docs)
        self.assertIn("``-entry methylation``", docs)
        self.assertIn("``-entry somatic_tumour_only_snv``", docs)
        self.assertIn("``-entry somatic_paired_snv_full_alignment``", docs)
        self.assertIn("``-entry somatic_paired_snv_merge``", docs)
        self.assertIn("``-entry somatic_qc``", docs)
        self.assertIn("``-entry somatic_tumour_only_sv``", docs)
        self.assertIn("``-entry somatic_annotation``", docs)
        self.assertIn("``-entry somatic_methylation_aggregation``", docs)
        self.assertIn("bounded mapping entry", docs)
        self.assertIn("bounded sample aggregation entry", docs)
        self.assertIn("bounded small-variant entry", docs)
        self.assertIn("bounded structural-variant entry", docs)
        self.assertIn("bounded CNV entry", docs)
        self.assertIn("bounded methylation entry", docs)
        self.assertIn("bounded ClairS-TO", docs)
        self.assertIn("bounded somatic QC", docs)
        self.assertIn("bounded Severus", docs)
        self.assertIn("bounded SnpEff/SnpSift", docs)
        self.assertIn("role-specific modkit aggregation", docs)
        self.assertIn("Task 15", docs)
        self.assertIn("Task 16", docs)
        self.assertIn("Task 17", docs)
        self.assertIn("Task 18", docs)
        self.assertIn("Task 19", docs)
        self.assertIn("Task 21", docs)
        self.assertIn("Task 22", docs)
        self.assertIn("Task 29", docs)
        self.assertIn("Task 30", docs)
        self.assertIn("Phase 4 task 11", docs)
        self.assertIn("Phase 4 task 15", docs)
        self.assertIn("Phase 4 task 16", docs)
        self.assertIn("family_mendelian_assessment", docs)
        self.assertIn("family analysis intent", docs.lower())
        self.assertIn("Dynamic Arrival", docs)
        self.assertIn("family_joint_vcf", docs)
        self.assertIn("family_joint_gvcf", docs)
        self.assertIn("structural_variant_snf", docs)
        self.assertIn("family_haplotagged_alignments", docs)
        self.assertIn("pedigree_snapshot", docs)
        self.assertIn("mendelian_summary", docs)
        self.assertIn("Inherited ``wf-trio`` reports are deprecated", docs)
        self.assertIn("Clair3-Nova", docs)
        self.assertIn("GLnexus", docs)
        self.assertIn("RTG", docs)
        self.assertIn("mapped_xam", docs)
        self.assertIn("aggregate_xam", docs)
        self.assertIn("aggregate_xam_index", docs)
        self.assertIn("mosdepth_summary", docs)
        self.assertIn("coverage_state", docs)
        self.assertIn("tumour_rejected_low_coverage", docs)
        self.assertIn("normal_rejected_low_coverage", docs)
        self.assertIn("somatic_pair_blocked_low_coverage", docs)
        self.assertIn("shared_role_artefacts", docs)
        self.assertIn("bam_tumor", docs)
        self.assertIn("bam_normal", docs)
        self.assertIn("snp_vcf", docs)
        self.assertIn("structural_variant_vcf", docs)
        self.assertIn("cnv_vcf", docs)
        self.assertIn("bedmethyl", docs)
        self.assertIn("somatic_snv_vcf", docs)
        self.assertIn("somatic_sv_vcf", docs)
        self.assertIn("somatic_tumour_only_snv_command_json", docs)
        self.assertIn("somatic_tumour_only_sv_command_json", docs)
        self.assertIn("optional_not_provided", docs)
        self.assertIn("duplicate aggregate artefacts", docs)
        self.assertIn("completion markers are reused", docs)
        self.assertIn("mapping bounded entry", ledger)
        self.assertIn("sample aggregation bounded entry", ledger)
        self.assertIn("small-variant bounded entry", ledger)
        self.assertIn("structural-variant bounded entry", ledger)
        self.assertIn("CNV bounded entry", ledger)
        self.assertIn("methylation bounded entry", ledger)
        self.assertIn("somatic_tumour_only_snv", ledger)
        self.assertIn("somatic_qc", ledger)
        self.assertIn("somatic_tumour_only_sv", ledger)


if __name__ == "__main__":
    unittest.main()
