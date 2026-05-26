#!/usr/bin/env python
"""Create machine-readable SV metrics JSON from VCF files."""

import gzip
import json

from .metrics import CHROMOSOMES
from .util import wf_parser


def argparser():
    """Create argument parser."""
    parser = wf_parser("sv_stats_json")
    parser.add_argument("--vcf", nargs="+", required=True, help="SV VCF file(s)")
    parser.add_argument(
        "--output_json",
        default="svs.json",
        required=False,
        help="Output JSON file",
    )
    return parser


def main(args):
    """Run entry point."""
    metrics = count_sv_types(args.vcf)
    with open(args.output_json, "w") as json_file:
        json.dump(metrics, json_file)


def count_sv_types(vcf_paths):
    """Count insertion, deletion, and other SV calls across VCF files."""
    inserts = 0
    deletions = 0
    other = 0
    for vcf_path in vcf_paths:
        for chrom, info in _iter_vcf_records(vcf_path):
            normalized_chrom = chrom.replace("chr", "")
            if normalized_chrom not in CHROMOSOMES:
                continue
            sv_type = _parse_info(info).get("SVTYPE", "")
            if sv_type == "INS":
                inserts += 1
            elif sv_type == "DEL":
                deletions += 1
            else:
                other += 1
    return {
        "SV insertions": int(inserts),
        "SV deletions": int(deletions),
        "Other SVs": int(other),
    }


def _iter_vcf_records(vcf_path):
    opener = gzip.open if str(vcf_path).endswith(".gz") else open
    with opener(vcf_path, "rt") as handle:
        for line in handle:
            if line.startswith("#"):
                continue
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 8:
                yield parts[0], parts[7]


def _parse_info(info):
    parsed = {}
    for item in info.split(";"):
        if "=" in item:
            key, value = item.split("=", 1)
            parsed[key] = value
        elif item:
            parsed[item] = ""
    return parsed
