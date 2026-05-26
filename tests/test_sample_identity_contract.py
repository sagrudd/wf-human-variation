"""Static contract tests for transitional sample identity handling."""

from pathlib import Path
import json
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]


def read(path):
    """Read a repository file."""
    return (REPO_ROOT / path).read_text()


class SampleIdentityContractTest(unittest.TestCase):
    """Verify sample_id and display alias can intentionally diverge."""

    def test_identity_sensitive_tool_arguments_use_sample_id(self):
        checked_paths = [
            "modules/local/wf-human-snp.nf",
            "modules/local/wf-human-sv.nf",
            "modules/local/wf-human-cnv.nf",
            "modules/local/wf-human-cnv-qdnaseq.nf",
            "modules/local/wf-human-str.nf",
        ]
        combined = "\n".join(read(path) for path in checked_paths)

        forbidden = [
            "--sampleName ${xam_meta.alias}",
            "--sampleName !{xam_meta.alias}",
            "--sample_name=${xam_meta.alias}",
            "--sample_name ${xam_meta.alias}",
            "--sample-id ${xam_meta.alias}",
            "--sample ${xam_meta.alias}",
            "--sample_id ${xam_meta.alias}",
        ]
        for token in forbidden:
            with self.subTest(token=token):
                self.assertNotIn(token, combined)

        required = [
            "--sampleName ${xam_meta.sample_id}",
            "--sampleName !{xam_meta.sample_id}",
            "--sample-id ${xam_meta.sample_id}",
            "--sample ${xam_meta.sample_id}",
            "--sample_id ${xam_meta.sample_id}",
        ]
        for token in required:
            with self.subTest(token=token):
                self.assertIn(token, combined)

    def test_metrics_and_rejection_state_record_sample_id_and_alias(self):
        common = read("modules/local/common.nf")

        self.assertIn('"sample_id": "${xam_meta.sample_id}"', common)
        self.assertIn('"display_alias": "${xam_meta.alias}"', common)
        self.assertIn(
            '--metadata \\\n'
            '              "sample_id=${xam_meta.sample_id}" \\\n'
            '              "display_alias=${xam_meta.alias}" \\\n'
            '              "sample_sheet.alias=${xam_meta.alias}"',
            common,
        )

    def test_sample_join_key_has_no_alias_fallback(self):
        keyed_joins = read("lib/keyed_joins.nf")

        self.assertIn("def key = meta.sample_id", keyed_joins)
        self.assertNotIn("?: meta.alias", keyed_joins)

    def test_family_grouping_uses_sample_id_with_alias_payload(self):
        methyl = read("workflows/methyl.nf")
        partners = read("workflows/partners.nf")
        str_workflow = read("workflows/wf-human-str.nf")

        self.assertIn(
            "[sample_id: meta.sample_id, alias: meta.alias, "
            "display_alias: meta.display_alias]",
            methyl,
        )
        self.assertIn("[meta.sample_id, meta, vcf, tbi]", partners)
        self.assertIn("groupTuple(by: 0)", partners)
        self.assertIn(
            "[alias: meta.alias, sample_id: meta.sample_id, "
            "display_alias: meta.display_alias]",
            str_workflow,
        )

    def test_alias_remains_filename_compatibility_label(self):
        snp = read("modules/local/wf-human-snp.nf")
        sv = read("modules/local/wf-human-sv.nf")

        self.assertIn('${xam_meta.alias}.wf_snp.vcf.gz', snp)
        self.assertIn('${xam_meta.alias}.wf_sv.vcf.gz', sv)

    def test_ingress_no_longer_hard_stops_on_multiple_records(self):
        ingress_wrapper = read("lib/_ingress.nf")

        self.assertNotIn("Too many samples found", ingress_wrapper)
        self.assertNotIn("ingressed_bam.count().subscribe", ingress_wrapper)

    def test_sample_id_mapping_supports_multi_record_launches(self):
        stable_identity = read("lib/stable_identity.nf")
        docs = read("docs/ingress.rst")

        self.assertIn("def parseSampleIdMap", stable_identity)
        self.assertIn("sampleIdMap[meta.alias] ?: sampleIdMap[meta.barcode]", stable_identity)
        self.assertIn("No --sample_id mapping found for alias", stable_identity)
        self.assertIn("--sample_id alias_a=smp_a,alias_b=smp_b", docs)

    def test_downsampling_and_coverage_use_keyed_sample_state(self):
        main = read("main.nf")
        common = read("modules/local/common.nf")

        self.assertIn("tuple val(xam_meta.sample_id), val(xam_meta), env(to_downsample)", common)
        self.assertIn(".join(ratio.subset, by: 0)", main)
        self.assertIn(".join(ratio.ready, by: 0)", main)
        self.assertIn(".join(ready_bam_keyed, by: 0, remainder: true)", main)
        self.assertIn(".combine(pass_bam_keyed, by: 0)", main)
        self.assertNotIn(".combine(pass_bam_channel)", main)
        self.assertNotIn(".combine(ratio.subset)", main)
        self.assertNotIn(".combine(ratio.ready)", main)

    def test_low_coverage_rejection_is_sample_state_not_workflow_failure(self):
        common = read("modules/local/common.nf")
        process_body = common.split("process rejectedLowCoverage", 1)[1].split(
            "process getVersions", 1
        )[0]

        self.assertIn('"state": "rejected_low_coverage"', process_body)
        self.assertIn('"workflow_status": "sample_rejected"', process_body)
        self.assertIn("unrelated samples can continue", process_body)
        self.assertNotIn("exit 1", process_body)

    def test_bounded_sample_aggregation_is_keyed_by_sample_and_reference(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_sample_aggregation.nf")

        self.assertIn("sample_id: _requiredBoundedParam(params, \"sample_id\")", helper)
        self.assertIn("reference_id: _requiredBoundedParam(params, \"reference_id\")", helper)
        self.assertIn('tag "${entry.sample_id}:${entry.reference_id}:${entry.task_key}"', module)
        self.assertIn('"sample_id": contract["sample_id"]', module)
        self.assertIn('"reference_id": contract["reference_id"]', module)
        self.assertNotIn("alias", module)
        self.assertNotIn("display_alias", module)

    def test_bounded_variant_calling_is_keyed_by_sample_reference_and_mode(self):
        helper = read("lib/bounded_entry.nf")
        module = read("modules/local/bounded_variant_calling.nf")

        self.assertIn("sample_id: _requiredBoundedParam(params, \"sample_id\")", helper)
        self.assertIn("reference_id: _requiredBoundedParam(params, \"reference_id\")", helper)
        self.assertIn("variant_mode: mode", helper)
        self.assertIn('tag "${entry.sample_id}:${entry.reference_id}:${entry.variant_mode}:${entry.task_key}"', module)
        self.assertIn('"sample_id": contract["sample_id"]', module)
        self.assertIn('"reference_id": contract["reference_id"]', module)
        self.assertIn('"variant_mode": contract["variant_mode"]', module)
        self.assertNotIn("alias", module)
        self.assertNotIn("display_alias", module)

    def test_runtime_docs_do_not_preserve_single_sample_enforcement(self):
        docs = "\n".join(
            read(path)
            for path in [
                "docs/ingress.rst",
                "docs/overview.rst",
                "docs/troubleshooting.rst",
                "docs/testing.rst",
            ]
        ).lower()

        self.assertNotIn("single-sample enforcement", docs)
        self.assertNotIn("only one sample is being ingressed", docs)
        self.assertNotIn("effective operation is single-sample", docs)

    def test_ingress_run_ids_are_not_mutated_into_params_wf(self):
        legacy_key = 'params.wf["' + 'ingress.' + 'run_ids' + '"]'
        checked = "\n".join(
            read(path)
            for path in [
                "main.nf",
                "lib/ingress.nf",
                "docs/architecture.rst",
                "docs/controller-execution.rst",
                "docs/maintenance.rst",
                "docs/workflow-control.rst",
            ]
        )

        self.assertNotIn(legacy_key, checked)
        self.assertIn("bam_runids.flatten()", read("main.nf"))
        self.assertIn("path \"${xam_meta.alias}.runids.txt\", emit: runids", read("modules/local/common.nf"))

    def test_ingress_run_ids_are_declared_machine_readable_outputs(self):
        outputs = json.loads(read("output_definition.json"))
        runids = outputs["files"]["ingress-run-ids"]

        self.assertEqual(runids["filepath"], "{{ alias }}.runids.txt")
        self.assertEqual(runids["mime-type"], "text/plain")
        self.assertEqual(runids["type"], "per-sample")
        self.assertIn("controller-owned manifest projection", runids["description"].lower())

    def test_optional_file_checks_are_centralized_at_boundary_helpers(self):
        checked_paths = [
            "main.nf",
            "modules/local/common.nf",
            "modules/local/wf-human-snp.nf",
            "modules/local/wf-human-sv.nf",
            "modules/local/wf-human-sv-eval.nf",
            "workflows/wf-human-sv.nf",
        ]
        combined = "\n".join(read(path) for path in checked_paths)

        forbidden = [
            "name != 'OPTIONAL_FILE'",
            'baseName != "OPTIONAL_FILE"',
            'startsWith("OPTIONAL_FILE")',
            'Channel.fromPath("OPTIONAL_FILE',
            "[meta, summary, OPTIONAL]",
        ]
        for token in forbidden:
            with self.subTest(token=token):
                self.assertNotIn(token, combined)

        self.assertIn("process eval_downsampling_without_bed", read("modules/local/common.nf"))
        self.assertIn("process evaluateCoveragePassWholeGenome", read("modules/local/common.nf"))
        self.assertIn("optionalBoundaryPath(\"vcf.gz\")", read("workflows/wf-human-sv.nf"))
        self.assertNotIn("filter{!isOptionalBoundaryFile(it)}", read("main.nf"))
        self.assertIn("bed_summary = Channel.empty()", read("main.nf"))
        self.assertIn("coverage_bed_summary = Channel.empty()", read("main.nf"))
        self.assertIn("sniffles_vcf = Channel.empty()", read("main.nf"))
        self.assertIn("mosdepth_perbase = Channel.empty()", read("workflows/wf-human-cnv.nf"))

    def test_remaining_optional_file_boundaries_are_documented(self):
        architecture = read("docs/architecture.rst")

        expected = [
            "absent haplocheck",
            "absent SNP genotyping VCF",
            "absent partner-export VCF inputs",
            "absent SV benchmark truthset paths",
            "Downsampling and coverage pass/fail no longer use placeholder files",
            "channels use empty channels",
        ]
        for token in expected:
            with self.subTest(token=token):
                self.assertIn(token, architecture)


if __name__ == "__main__":
    unittest.main()
