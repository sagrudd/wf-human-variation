"""Synthetic fixture-backed contracts for phase 2 task 23."""

from __future__ import annotations

import csv
import importlib.util
import io
import json
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = Path(__file__).parent / "fixtures" / "synthetic"
sys.path.insert(0, str(ROOT / "bin"))


class Phase2SyntheticFixtureTest(unittest.TestCase):
    def test_text_fixtures_are_parseable_and_tiny(self):
        reference = FIXTURES / "reference.fa"
        bed = FIXTURES / "regions.named.bed"
        vcf = FIXTURES / "empty.vcf"
        low_summary = FIXTURES / "mosdepth.low.summary.txt"
        pass_summary = FIXTURES / "mosdepth.pass.summary.txt"
        ped = FIXTURES / "family.ped"
        family_gvcfs = (
            FIXTURES / "smp_child.g.vcf",
            FIXTURES / "smp_father.g.vcf",
            FIXTURES / "smp_mother.g.vcf",
        )

        self.assertEqual(reference.read_text().splitlines(), [">chrSynthetic", "ACGTACGTACGTACGTACGTACGTACGTACGT"])
        self.assertEqual(
            [line.split("\t") for line in bed.read_text().splitlines()],
            [["chrSynthetic", "0", "16", "target_1"], ["chrSynthetic", "16", "32", "target_2"]],
        )
        vcf_rows = [line.split("\t") for line in vcf.read_text().splitlines() if not line.startswith("##")]
        self.assertEqual(vcf_rows[0][:5], ["#CHROM", "POS", "ID", "REF", "ALT"])
        self.assertEqual(vcf_rows[0][-1], "smp_fixture")
        self.assertEqual(
            [line.split("\t") for line in ped.read_text().splitlines()],
            [
                ["FAM001", "smp_child", "smp_father", "smp_mother", "0", "2"],
                ["FAM001", "smp_father", "0", "0", "1", "1"],
                ["FAM001", "smp_mother", "0", "0", "2", "1"],
            ],
        )
        for gvcf in family_gvcfs:
            rows = [line.split("\t") for line in gvcf.read_text().splitlines() if not line.startswith("##")]
            self.assertEqual(rows[0][:5], ["#CHROM", "POS", "ID", "REF", "ALT"])
            self.assertEqual(rows[0][-1], gvcf.name.removesuffix(".g.vcf"))
            self.assertEqual(rows[1][:5], ["chrSynthetic", "5", ".", "A", "C"])
        self.assertEqual(self._coverage_state(low_summary, 20), "rejected_low_coverage")
        self.assertEqual(self._coverage_state(pass_summary, 20), "coverage_passed")
        for path in (reference, bed, vcf, low_summary, pass_summary, ped, *family_gvcfs):
            self.assertLess(path.stat().st_size, 1024)

    def test_sample_sheet_fixture_order_does_not_change_sample_identity(self):
        first = self._sample_sheet_rows(FIXTURES / "sample_sheet.two_a.csv")
        second = self._sample_sheet_rows(FIXTURES / "sample_sheet.two_b.csv")

        self.assertEqual(
            sorted((row["sample_id"], row["alias"], row["barcode"]) for row in first),
            sorted((row["sample_id"], row["alias"], row["barcode"]) for row in second),
        )
        self._assert_sample_sheet_valid(FIXTURES / "sample_sheet.two_a.csv")
        self._assert_sample_sheet_valid(FIXTURES / "sample_sheet.two_b.csv")

    def test_sample_sheet_duplicate_fixtures_are_rejected(self):
        self._assert_sample_sheet_invalid(FIXTURES / "sample_sheet.duplicate_alias.csv", "alias")
        self._assert_sample_sheet_invalid(FIXTURES / "sample_sheet.duplicate_barcode.csv", "barcode")

    def test_generated_xam_fixtures_cover_mapped_and_unmapped_inputs_when_pysam_is_available(self):
        try:
            from workflow_glue.check_mapped_reads import main as check_mapped_reads
        except ModuleNotFoundError as error:
            if error.name == "pysam":
                raise unittest.SkipTest("pysam is not installed in this local Python") from error
            raise
        generator = self._load_xam_generator()

        generator.generate(FIXTURES)
        try:
            self.assertEqual(self._mapped_read_flag(check_mapped_reads, FIXTURES / "mapped.bam"), "has_maps=1;")
            self.assertEqual(self._mapped_read_flag(check_mapped_reads, FIXTURES / "unmapped.bam"), "has_maps=0;")
            self.assertTrue((FIXTURES / "mapped.cram").exists())
            self.assertTrue((FIXTURES / "mapped.cram.crai").exists())
        finally:
            for name in ("mapped.bam", "mapped.bam.bai", "unmapped.bam", "unmapped.bam.bai", "mapped.cram", "mapped.cram.crai"):
                try:
                    (FIXTURES / name).unlink()
                except FileNotFoundError:
                    pass

    def test_public_output_contract_declares_no_html_reports(self):
        for relative in ("output_definition.json", "nextflow_schema.json"):
            data = json.loads((ROOT / relative).read_text())
            self.assertNotIn("output_report", self._flatten_keys(data))
            self.assertFalse(
                [
                    value
                    for value in self._flatten_values(data)
                    if isinstance(value, str) and value.lower().endswith((".html", ".htm"))
                ],
                relative,
            )

    def test_feature_prerequisite_contracts_are_explicit(self):
        text = (ROOT / "lib" / "feature_prerequisites.nf").read_text()

        self.assertIn('family == "str"', text)
        self.assertIn('required_output_kind: "haplotagged_contig_bams"', text)
        self.assertIn('missing_policy: "plan"', text)
        self.assertIn('family == "cnv" && (!selectedMode || selectedMode == "spectre")', text)
        self.assertIn('required_output_kind: "snp_vcf"', text)
        self.assertIn('family == "methylation" && ["phased", "haplotagged"].contains(selectedMode)', text)
        self.assertIn('required_output_kind: "haplotagged_bam"', text)
        self.assertIn('missing_policy: "degrade"', text)
        self.assertIn('family == "reporting"', text)
        self.assertIn('type: "task_family_subset"', text)
        self.assertIn("minimum_count: 1", text)
        self.assertIn('missing_policy: "block"', text)

    @staticmethod
    def _coverage_state(path: Path, threshold: float) -> str:
        with path.open() as handle:
            for row in csv.DictReader(handle, delimiter="\t"):
                if row["chrom"] == "total_region":
                    return "coverage_passed" if float(row["mean"]) >= threshold else "rejected_low_coverage"
        return "rejected_low_coverage"

    @staticmethod
    def _sample_sheet_rows(path: Path) -> list[dict[str, str]]:
        with path.open() as handle:
            return list(csv.DictReader(handle))

    def _assert_sample_sheet_valid(self, path: Path) -> None:
        from workflow_glue.wfg_helpers.check_sample_sheet import main as check_sample_sheet

        check_sample_sheet(SimpleNamespace(sample_sheet=str(path), required_sample_types=[]))

    def _assert_sample_sheet_invalid(self, path: Path, message: str) -> None:
        from workflow_glue.wfg_helpers.check_sample_sheet import main as check_sample_sheet

        output = io.StringIO()
        with redirect_stdout(output), self.assertRaises(SystemExit):
            check_sample_sheet(SimpleNamespace(sample_sheet=str(path), required_sample_types=[]))
        self.assertIn(message, output.getvalue())

    def _mapped_read_flag(self, check_mapped_reads, path: Path) -> str:
        output = io.StringIO()
        with redirect_stdout(output), self.assertRaises(SystemExit):
            check_mapped_reads(SimpleNamespace(xam=str(path)))
        return output.getvalue()

    @staticmethod
    def _load_xam_generator():
        script = FIXTURES / "make_xam_fixtures.py"
        spec = importlib.util.spec_from_file_location("make_xam_fixtures", script)
        if spec is None or spec.loader is None:
            raise RuntimeError(f"could not load fixture generator: {script}")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

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
    def _flatten_values(cls, value: object) -> list[object]:
        if isinstance(value, dict):
            result: list[object] = []
            for item in value.values():
                result.extend(cls._flatten_values(item))
            return result
        if isinstance(value, list):
            result = []
            for item in value:
                result.extend(cls._flatten_values(item))
            return result
        return [value]


if __name__ == "__main__":
    unittest.main()
