#!/usr/bin/env python
"""Create machine-readable SNP metrics JSON from bcftools stats."""

import json

from .util import wf_parser


def argparser():
    """Create argument parser."""
    parser = wf_parser("snp_stats_json")
    parser.add_argument("--vcf_stats", required=True, help="bcftools stats file")
    parser.add_argument("--sample_name", required=True, help="Sample name")
    parser.add_argument("--output", required=True, help="Output JSON file")
    return parser


def main(args):
    """Run entry point."""
    metrics = parse_bcfstats(args.vcf_stats)
    with open(args.output, "w") as json_file:
        json.dump(metrics, json_file)


def parse_bcfstats(vcf_stats):
    """Extract the SNP metrics consumed by combined workflow statistics."""
    metrics = {
        "SNVs": 0,
        "Indels": 0,
        "Transition/Transversion rate": None,
    }
    with open(vcf_stats) as handle:
        for line in handle:
            if line.startswith("#"):
                continue
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 4:
                continue
            record_type = parts[0]
            if record_type == "SN":
                label = parts[2].strip().lower()
                value = _to_int(parts[3])
                if label == "number of snps:":
                    metrics["SNVs"] = value
                elif label == "number of indels:":
                    metrics["Indels"] = value
            elif record_type == "TSTV" and len(parts) > 4:
                metrics["Transition/Transversion rate"] = _to_float(parts[4])
    return metrics


def _to_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _to_int(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0
