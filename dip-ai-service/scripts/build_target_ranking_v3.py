from pathlib import Path
import sys

import pandas as pd

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import PROCESSED_DIR
from app.models.explainability import add_ranking_explanations_v3
from app.models.ranking_engine import rank_targets_v3


INPUT_FILE = PROCESSED_DIR / "target_features_v2.csv"
OUTPUT_FILE = PROCESSED_DIR / "target_ranking_v3.csv"
SUMMARY_FILE = PROCESSED_DIR / "target_ranking_v3_summary.txt"

SUMMARY_COLUMNS = [
    "gene_name",
    "mutation_count",
    "mutated_patients",
    "mean_tumor_expression",
    "mutation_frequency_score",
    "expression_score",
    "protein_impact_score",
    "luad_relevance_score",
    "targetability_score",
    "dormancy_evidence_score",
    "passenger_penalty",
    "ranking_score_v3",
    "priority_v3",
    "explanation_v3",
]


def build_summary(ranked: pd.DataFrame) -> str:
    """
    Build a plain-text summary for the V3 target ranking output.

    Args:
        ranked: Ranked target dataframe with explanations.

    Returns:
        Summary text ready to write to disk.
    """
    priority_counts = ranked["priority_v3"].value_counts()
    top_40 = ranked.loc[:, SUMMARY_COLUMNS].head(40).to_string(index=False)

    return (
        "DIP-AI Target Ranking V3 Summary\n"
        "=================================\n"
        f"Input file: {INPUT_FILE}\n"
        f"Output file: {OUTPUT_FILE}\n"
        f"Total rows: {len(ranked)}\n"
        f"High priority: {priority_counts.get('High', 0)}\n"
        f"Medium priority: {priority_counts.get('Medium', 0)}\n"
        f"Low priority: {priority_counts.get('Low', 0)}\n"
        "\nTop 40 genes by ranking_score_v3:\n"
        f"{top_40}\n"
    )


def main() -> None:
    """Build and save the V3 target ranking table from V2 feature inputs."""
    if not INPUT_FILE.exists():
        raise FileNotFoundError(f"Required V2 feature table not found: {INPUT_FILE}")

    features = pd.read_csv(INPUT_FILE)
    ranked = rank_targets_v3(features)
    ranked = add_ranking_explanations_v3(ranked)

    ranked.to_csv(OUTPUT_FILE, index=False)
    SUMMARY_FILE.write_text(build_summary(ranked), encoding="utf-8")

    print("Target ranking V3 built successfully.")
    print(f"Saved ranking table: {OUTPUT_FILE}")
    print(f"Saved summary: {SUMMARY_FILE}")
    print("\nTop 40 genes:")
    print(ranked.loc[:, SUMMARY_COLUMNS].head(40).to_string(index=False))


if __name__ == "__main__":
    main()
