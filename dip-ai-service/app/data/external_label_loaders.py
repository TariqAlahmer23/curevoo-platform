"""Load external biomedical evidence labels for gene-level ML benchmarks."""

from __future__ import annotations

from pathlib import Path

import pandas as pd


EXTERNAL_LABEL_COLUMNS = [
    "gene_name",
    "source",
    "evidence_type",
    "evidence_score",
    "label",
]


def load_external_label_file(path: Path) -> pd.DataFrame:
    """
    Load and validate one external gene-label evidence CSV.

    Expected columns:
    ``gene_name,source,evidence_type,evidence_score,label``.
    """
    if not path.exists():
        raise FileNotFoundError(f"External label file not found: {path}")

    evidence = pd.read_csv(path, low_memory=False)
    missing_columns = [
        column for column in EXTERNAL_LABEL_COLUMNS if column not in evidence.columns
    ]
    if missing_columns:
        raise ValueError(
            f"External label file {path} missing required columns: {missing_columns}"
        )

    evidence = evidence.loc[:, EXTERNAL_LABEL_COLUMNS].copy()
    evidence["gene_name"] = (
        evidence["gene_name"].astype("string").str.strip().str.upper()
    )
    evidence["source"] = evidence["source"].astype("string").str.strip()
    evidence["evidence_type"] = evidence["evidence_type"].astype("string").str.strip()
    evidence["evidence_score"] = pd.to_numeric(
        evidence["evidence_score"], errors="coerce"
    )
    evidence["label"] = pd.to_numeric(evidence["label"], errors="coerce")

    evidence = evidence.dropna(subset=["gene_name"])
    evidence = evidence[evidence["gene_name"] != ""]

    invalid_label_mask = evidence["label"].isna() | ~evidence["label"].isin([0, 1])
    if invalid_label_mask.any():
        examples = sorted(evidence.loc[invalid_label_mask, "label"].astype(str).unique())[:5]
        raise ValueError(
            f"External label file {path} has missing or non-binary labels: {examples}"
        )

    evidence["label"] = evidence["label"].astype(int)
    evidence["source_file"] = path.name

    return evidence


def load_all_external_label_sources(labels_dir: Path) -> pd.DataFrame:
    """Load and concatenate all external evidence-label CSV files in a directory."""
    labels_dir.mkdir(parents=True, exist_ok=True)
    label_files = sorted(labels_dir.glob("*.csv"))
    if not label_files:
        return pd.DataFrame(columns=[*EXTERNAL_LABEL_COLUMNS, "source_file"])

    evidence_tables = [load_external_label_file(path) for path in label_files]
    if not evidence_tables:
        return pd.DataFrame(columns=[*EXTERNAL_LABEL_COLUMNS, "source_file"])

    return pd.concat(evidence_tables, ignore_index=True)
