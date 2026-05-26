"""Tests for machine-readable workflow metric helpers."""

from workflow_glue import get_components
from workflow_glue.metrics import compute_n50
from workflow_glue.snp_stats_json import parse_bcfstats
from workflow_glue.sv_stats_json import count_sv_types


def test_metrics_module_is_not_a_cli_command():
    """Metrics helpers should not appear as a workflow-glue subcommand."""
    assert "metrics" not in get_components()


def test_parse_bcfstats(tmp_path):
    """SNP JSON metrics are extracted without report dependencies."""
    stats = tmp_path / "variants.stats"
    stats.write_text(
        "SN\t0\tnumber of SNPs:\t12\n"
        "SN\t0\tnumber of indels:\t3\n"
        "TSTV\t0\t8\t4\t2.0\n"
    )

    assert parse_bcfstats(stats) == {
        "SNVs": 12,
        "Indels": 3,
        "Transition/Transversion rate": 2.0,
    }


def test_count_sv_types(tmp_path):
    """SV JSON metrics are extracted without report dependencies."""
    vcf = tmp_path / "sv.vcf"
    vcf.write_text(
        "##fileformat=VCFv4.2\n"
        "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\n"
        "chr1\t1\t.\tN\t<INS>\t.\tPASS\tSVTYPE=INS\n"
        "2\t2\t.\tN\t<DEL>\t.\tPASS\tSVTYPE=DEL\n"
        "chrUn\t3\t.\tN\t<DUP>\t.\tPASS\tSVTYPE=DUP\n"
        "X\t4\t.\tN\t<DUP>\t.\tPASS\tSVTYPE=DUP\n"
    )

    assert count_sv_types([vcf]) == {
        "SV insertions": 1,
        "SV deletions": 1,
        "Other SVs": 1,
    }


def test_compute_n50_from_lengths():
    """The retained N50 helper handles plain length arrays."""
    assert compute_n50([10, 20, 30]) == 30
