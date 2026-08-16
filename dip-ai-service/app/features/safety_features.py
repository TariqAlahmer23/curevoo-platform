"""GTEx Lung safety feature engineering for DIP-AI target ranking."""

from pathlib import Path

import pandas as pd


SAFETY_NOTE = (
    "Higher normal lung expression may reduce target safety priority because "
    "on-target activity in normal lung tissue could increase safety risk."
)


def find_gtex_median_tpm_file(gtex_dir: Path) -> Path:
    """
    Find the GTEx median TPM GCT file in a directory.

    Args:
        gtex_dir: Directory containing GTEx files.

    Returns:
        Path to the first matching GTEx median TPM file.
    """
    matches = sorted(gtex_dir.glob("*gene_median_tpm*.gct.gz"))
    if not matches:
        raise FileNotFoundError(
            f"No GTEx median TPM GCT file found in {gtex_dir} matching "
            "'*gene_median_tpm*.gct.gz'"
        )

    return matches[0]


def load_gtex_lung_expression(gtex_file: Path) -> pd.DataFrame:
    """
    Load normal lung expression from a GTEx median TPM GCT file.

    Args:
        gtex_file: Path to the GTEx GCT gzip file.

    Returns:
        Dataframe with ``gene_name`` and ``normal_lung_tpm`` columns.
    """
    gtex = pd.read_csv(gtex_file, sep="\t", skiprows=2)
    if "Lung" not in gtex.columns:
        raise ValueError(f"GTEx file missing required Lung column: {gtex_file}")
    if "Name" not in gtex.columns:
        raise ValueError(f"GTEx file missing required Name column: {gtex_file}")

    gene_source_column = "Description" if "Description" in gtex.columns else "Name"
    lung_expression = pd.DataFrame(
        {
            "gene_name": gtex[gene_source_column],
            "normal_lung_tpm": pd.to_numeric(gtex["Lung"], errors="coerce"),
        }
    )
    lung_expression["gene_name"] = lung_expression["gene_name"].astype("string").str.strip()
    lung_expression = lung_expression.dropna(subset=["gene_name"])
    lung_expression = lung_expression[lung_expression["gene_name"] != ""]

    return (
        lung_expression.groupby("gene_name", as_index=False)["normal_lung_tpm"]
        .max()
        .sort_values("gene_name")
        .reset_index(drop=True)
    )


def assign_safety_score(normal_lung_tpm: float) -> float:
    """
    Assign a safety score from normal lung TPM.

    Higher scores indicate lower normal-lung expression and less safety concern.
    """
    if pd.isna(normal_lung_tpm):
        return 0.50
    if normal_lung_tpm < 1:
        return 1.00
    if normal_lung_tpm < 10:
        return 0.75
    if normal_lung_tpm < 50:
        return 0.45

    return 0.20


def assign_safety_risk(normal_lung_tpm: float) -> str:
    """Assign a safety risk label from normal lung TPM."""
    if pd.isna(normal_lung_tpm):
        return "Unknown"
    if normal_lung_tpm < 1:
        return "Low_Normal_Expression"
    if normal_lung_tpm < 10:
        return "Moderate_Normal_Expression"
    if normal_lung_tpm < 50:
        return "High_Normal_Expression"

    return "Very_High_Normal_Expression"


def build_gtex_lung_safety_features(gtex_dir: Path) -> pd.DataFrame:
    """
    Build GTEx Lung safety features from the local median TPM file.

    Args:
        gtex_dir: Directory containing the GTEx median TPM GCT file.

    Returns:
        Gene-level safety feature dataframe.
    """
    gtex_file = find_gtex_median_tpm_file(gtex_dir)
    safety_features = load_gtex_lung_expression(gtex_file)
    safety_features["safety_score"] = safety_features["normal_lung_tpm"].apply(
        assign_safety_score
    )
    safety_features["safety_risk"] = safety_features["normal_lung_tpm"].apply(
        assign_safety_risk
    )
    safety_features["safety_note"] = SAFETY_NOTE

    return safety_features
