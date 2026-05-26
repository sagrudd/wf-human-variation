"""Static contract tests for transitional sample identity handling."""

from pathlib import Path
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


if __name__ == "__main__":
    unittest.main()
