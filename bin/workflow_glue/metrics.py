"""Machine-readable metric helpers for workflow glue commands."""

import os

import numpy as np
import pandas as pd

CHROMOSOMES = {str(i): i for i in range(1, 23)}
CHROMOSOMES.update({f"chr{i}": int(i) for i in CHROMOSOMES})
CHROMOSOMES.update({'X': 23, 'Y': 24, 'chrX': 23, 'chrY': 24})


def compute_n50(data, x='start', y='count'):
    """Compute N50 from a histogram, array, list, or tuple."""
    if isinstance(data, pd.DataFrame):
        return n50_hist(data, x=x, y=y)
    if isinstance(data, np.ndarray):
        return n50_array(data)
    if isinstance(data, (list, tuple)):
        return n50_array(np.array(data))
    raise ValueError(f"Unsupported data type {type(data)}")


def histogram_median(hist, x='start', y='count'):
    """Compute a weighted median from histogram bin values and counts."""
    if hist.empty:
        return 0
    ordered = hist.sort_values(by=x)
    counts = ordered[y].to_numpy()
    total = counts.sum()
    if total == 0:
        return 0
    midpoint = total / 2
    return ordered.iloc[np.searchsorted(np.cumsum(counts), midpoint)][x]


def load_mosdepth_summary(summary_path):
    """Load a mosdepth summary file as total and all-row dataframes."""
    columns = ["chrom", "length", "bases", "mean", "min", "max"]
    summary = pd.read_csv(summary_path, sep="\t")
    if not set(columns).issubset(summary.columns):
        summary = pd.read_csv(summary_path, sep="\t", names=columns)
    total = summary[summary["chrom"].astype(str).isin(["total", "total_region"])]
    return total, summary


def n50_array(lengths):
    """Compute read N50 from an array of lengths."""
    sorted_l = np.sort(lengths)[::-1]
    cumsum = np.cumsum(sorted_l)
    return sorted_l[np.searchsorted(cumsum, cumsum[-1]/2)]


def n50_hist(length_hist, x='start', y='count'):
    """Compute read N50 from histogram data."""
    if length_hist.empty:
        return 0
    cumsum = np.cumsum(length_hist[y].values * length_hist[x].values)
    return length_hist.iloc[np.searchsorted(cumsum, cumsum[-1]/2)].start


def sum_hists(mapped_hist, unmapped_hist):
    """Sum two histogram dataframes based on their intervals."""
    return pd.concat([mapped_hist, unmapped_hist]) \
        .reset_index(drop=True) \
        .sort_values(by='start') \
        .groupby(['start', 'end']) \
        .sum().reset_index()


def load_hists(hists_dir, dtype):
    """Load and combine mapped and unmapped histogram data."""
    dt = int if "length" in dtype else float
    hist_map = _load_hist(os.path.join(hists_dir, f"{dtype}.hist"), dt)
    if dtype in ['length', 'quality']:
        hist_umap = _load_hist(os.path.join(hists_dir, f"{dtype}.unmap.hist"), dt)
    else:
        hist_umap = _empty_hist(dt)
    return sum_hists(hist_map, hist_umap), hist_map, hist_umap


def _empty_hist(dt):
    return pd.DataFrame(columns=["start", "end", "count"]) \
        .astype({"start": dt, "end": dt, "count": int})


def _load_hist(path, dt):
    try:
        return pd.read_csv(
            path,
            sep="\t",
            names=["start", "end", "count"],
            dtype={"start": dt, "end": dt, "count": int},
        )
    except Exception:
        return _empty_hist(dt)
