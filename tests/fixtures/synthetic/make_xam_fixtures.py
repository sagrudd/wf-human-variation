#!/usr/bin/env python3
"""Generate tiny mapped/unmapped BAM and mapped CRAM fixtures.

The repository does not commit binary XAM files. This helper is used by local
tests when ``pysam`` is installed and can also be run manually to inspect the
fixture shape.
"""

from __future__ import annotations

from pathlib import Path

import pysam


def _write(path: Path, mode: str, *, mapped: bool, reference: Path) -> None:
    header = {
        "HD": {"VN": "1.6", "SO": "coordinate"},
        "SQ": [{"SN": "chrSynthetic", "LN": 32}],
        "RG": [{"ID": "rg_fixture", "SM": "smp_fixture"}],
    }
    kwargs = {"header": header}
    if mode == "wc":
        kwargs["reference_filename"] = str(reference)
    with pysam.AlignmentFile(path, mode, **kwargs) as handle:
        read = pysam.AlignedSegment()
        read.query_name = "read_fixture_001"
        read.query_sequence = "ACGTACGT"
        read.query_qualities = pysam.qualitystring_to_array("FFFFFFFF")
        read.set_tag("RG", "rg_fixture")
        if mapped:
            read.flag = 0
            read.reference_id = 0
            read.reference_start = 0
            read.mapping_quality = 60
            read.cigar = ((0, 8),)
        else:
            read.flag = 4
            read.reference_id = -1
            read.reference_start = -1
            read.mapping_quality = 0
        handle.write(read)


def generate(directory: Path) -> None:
    reference = directory / "reference.fa"
    _write(directory / "mapped.bam", "wb", mapped=True, reference=reference)
    pysam.index(str(directory / "mapped.bam"))
    _write(directory / "unmapped.bam", "wb", mapped=False, reference=reference)
    pysam.index(str(directory / "unmapped.bam"))
    _write(directory / "mapped.cram", "wc", mapped=True, reference=reference)
    pysam.index(str(directory / "mapped.cram"))


if __name__ == "__main__":
    generate(Path(__file__).resolve().parent)
