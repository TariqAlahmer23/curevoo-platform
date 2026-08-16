from pathlib import Path
import sys

import pandas as pd

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import GTEX_DIR, PROCESSED_DIR
from app.features.safety_features import (
    build_gtex_lung_safety_features,
    find_gtex_median_tpm_file,
)


OUTPUT_FILE = PROCESSED_DIR / "gtex_lung_safety_features.csv"
SUMMARY_FILE = PROCESSED_DIR / "gtex_lung_safety_features_summary.txt"


def build_summary(safety_features: pd.DataFrame, gtex_file: Path) -> str:
    """
    Build a plain-text summary for GTEx Lung safety features.

    Args:
        safety_features: Gene-level GTEx Lung safety dataframe.
        gtex_file: GTEx file used to build the features.

    Returns:
        Summary text ready to write to disk.
    """
    risk_counts = safety_features["safety_risk"].value_counts().to_string()
    highest_tpm = (
        safety_features.sort_values("normal_lung_tpm", ascending=False)
        .head(30)
        .to_string(index=False)
    )
    safest_low_expression = (
        safety_features[
            safety_features["safety_risk"] == "Low_Normal_Expression"
        ]
        .sort_values(["normal_lung_tpm", "gene_name"], ascending=[True, True])
        .head(30)
        .to_string(index=False)
    )

    return (
        "DIP-AI GTEx Lung Safety Features Summary\n"
        "=========================================\n"
        f"GTEx file used: {gtex_file}\n"
        f"Total genes: {len(safety_features)}\n"
        "\nSafety risk counts:\n"
        f"{risk_counts}\n"
        "\nTop 30 highest normal lung TPM genes:\n"
        f"{highest_tpm}\n"
        "\nFirst 30 safest low-expression genes:\n"
        f"{safest_low_expression}\n"
    )


def main() -> None:
    """Build and save GTEx Lung safety features."""
    gtex_file = find_gtex_median_tpm_file(GTEX_DIR)
    safety_features = build_gtex_lung_safety_features(GTEX_DIR)

    safety_features.to_csv(OUTPUT_FILE, index=False)
    SUMMARY_FILE.write_text(
        build_summary(safety_features, gtex_file),
        encoding="utf-8",
    )

    print("GTEx Lung safety features built successfully.")
    print(f"GTEx file used: {gtex_file}")
    print(f"Saved safety features: {OUTPUT_FILE}")
    print(f"Saved summary: {SUMMARY_FILE}")
    print("\nSafety risk counts:")
    print(safety_features["safety_risk"].value_counts().to_string())


if __name__ == "__main__":
    main()
