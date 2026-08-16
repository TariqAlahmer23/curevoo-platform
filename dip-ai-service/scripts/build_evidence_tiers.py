from pathlib import Path
import sys

import pandas as pd

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import PROCESSED_DIR
from app.models.evidence_tiering import add_evidence_tiers


INPUT_FILE = PROCESSED_DIR / "target_ranking_v4.csv"
OUTPUT_FILE = PROCESSED_DIR / "target_ranking_v5_evidence_tiers.csv"
SUMMARY_FILE = PROCESSED_DIR / "target_ranking_v5_evidence_tiers_summary.txt"

SUMMARY_COLUMNS = [
    "gene_name",
    "ranking_score_v4",
    "priority_v4",
    "evidence_tier",
    "target_category",
    "safety_score",
    "safety_risk",
    "luad_relevance_score",
    "targetability_score",
    "dormancy_evidence_score",
    "passenger_penalty",
    "evidence_tier_explanation",
    "explanation_v4",
]


def build_summary(tiered: pd.DataFrame) -> str:
    """
    Build a plain-text summary for the V5 evidence tier output.

    Args:
        tiered: Ranked target dataframe with evidence tiers.

    Returns:
        Summary text ready to write to disk.
    """
    evidence_tier_counts = tiered["evidence_tier"].value_counts().to_string()
    target_category_counts = tiered["target_category"].value_counts().to_string()
    top_50 = tiered.loc[:, SUMMARY_COLUMNS].head(50).to_string(index=False)

    return (
        "DIP-AI Target Ranking V5 Evidence Tiers Summary\n"
        "================================================\n"
        f"Input file: {INPUT_FILE}\n"
        f"Output file: {OUTPUT_FILE}\n"
        f"Total rows: {len(tiered)}\n"
        "\nEvidence tier counts:\n"
        f"{evidence_tier_counts}\n"
        "\nTarget category counts:\n"
        f"{target_category_counts}\n"
        "\nTop 50 genes by ranking_score_v4:\n"
        f"{top_50}\n"
    )


def main() -> None:
    """Build and save evidence tiers from the V4 target ranking."""
    if not INPUT_FILE.exists():
        raise FileNotFoundError(f"Required V4 ranking file not found: {INPUT_FILE}")

    ranked_v4 = pd.read_csv(INPUT_FILE)
    tiered = add_evidence_tiers(ranked_v4)

    tiered.to_csv(OUTPUT_FILE, index=False)
    SUMMARY_FILE.write_text(build_summary(tiered), encoding="utf-8")

    print("Evidence tiers built successfully.")
    print(f"Saved evidence tier table: {OUTPUT_FILE}")
    print(f"Saved summary: {SUMMARY_FILE}")
    print("\nEvidence tier counts:")
    print(tiered["evidence_tier"].value_counts().to_string())
    print("\nTarget category counts:")
    print(tiered["target_category"].value_counts().to_string())


if __name__ == "__main__":
    main()
