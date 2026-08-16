from pathlib import Path
import sys

import pandas as pd

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import PROCESSED_DIR
from app.models.explainability import add_ranking_explanations_v4
from app.models.ranking_engine import rank_targets_v4_with_safety


RANKING_V3_FILE = PROCESSED_DIR / "target_ranking_v3.csv"
SAFETY_FEATURES_FILE = PROCESSED_DIR / "gtex_lung_safety_features.csv"
OUTPUT_FILE = PROCESSED_DIR / "target_ranking_v4.csv"
SUMMARY_FILE = PROCESSED_DIR / "target_ranking_v4_summary.txt"

SUMMARY_COLUMNS = [
    "gene_name",
    "ranking_score_v3",
    "ranking_score_v4",
    "priority_v4",
    "normal_lung_tpm",
    "safety_score",
    "safety_risk",
    "safety_penalty",
    "luad_relevance_score",
    "targetability_score",
    "dormancy_evidence_score",
    "passenger_penalty",
    "explanation_v4",
]


def build_summary(ranked: pd.DataFrame) -> str:
    """
    Build a plain-text summary for the V4 target ranking output.

    Args:
        ranked: Ranked V4 target dataframe with explanations.

    Returns:
        Summary text ready to write to disk.
    """
    priority_counts = ranked["priority_v4"].value_counts()
    top_40 = ranked.loc[:, SUMMARY_COLUMNS].head(40).to_string(index=False)

    return (
        "DIP-AI Target Ranking V4 Summary\n"
        "=================================\n"
        f"V3 input file: {RANKING_V3_FILE}\n"
        f"Safety input file: {SAFETY_FEATURES_FILE}\n"
        f"Output file: {OUTPUT_FILE}\n"
        f"Total rows: {len(ranked)}\n"
        f"High priority: {priority_counts.get('High', 0)}\n"
        f"Medium priority: {priority_counts.get('Medium', 0)}\n"
        f"Low priority: {priority_counts.get('Low', 0)}\n"
        "\nTop 40 genes by ranking_score_v4:\n"
        f"{top_40}\n"
    )


def main() -> None:
    """Build and save the V4 target ranking table with GTEx Lung safety."""
    if not RANKING_V3_FILE.exists():
        raise FileNotFoundError(f"Required V3 ranking file not found: {RANKING_V3_FILE}")
    if not SAFETY_FEATURES_FILE.exists():
        raise FileNotFoundError(
            f"Required safety feature file not found: {SAFETY_FEATURES_FILE}"
        )

    ranked_v3 = pd.read_csv(RANKING_V3_FILE)
    safety_features = pd.read_csv(SAFETY_FEATURES_FILE)
    ranked_v4 = rank_targets_v4_with_safety(ranked_v3, safety_features)
    ranked_v4 = add_ranking_explanations_v4(ranked_v4)

    ranked_v4.to_csv(OUTPUT_FILE, index=False)
    SUMMARY_FILE.write_text(build_summary(ranked_v4), encoding="utf-8")

    print("Target ranking V4 built successfully.")
    print(f"Saved ranking table: {OUTPUT_FILE}")
    print(f"Saved summary: {SUMMARY_FILE}")
    print("\nTop 40 genes:")
    print(ranked_v4.loc[:, SUMMARY_COLUMNS].head(40).to_string(index=False))


if __name__ == "__main__":
    main()
