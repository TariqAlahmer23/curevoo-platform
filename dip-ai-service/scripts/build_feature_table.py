from pathlib import Path
import sys

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import PROCESSED_DIR
from app.data.loaders import load_all_data
from app.data.validators import validate_all_data
from app.features.target_features import build_target_feature_table


OUTPUT_FILE = PROCESSED_DIR / "target_features_v2.csv"
SUMMARY_FILE = PROCESSED_DIR / "target_features_v2_summary.txt"

TOP_COLUMNS = [
    "gene_name",
    "mutation_count",
    "mutated_patients",
    "nonsynonymous_mutation_count",
    "mean_tumor_expression",
    "mutation_frequency_score",
    "expression_score",
    "protein_impact_score",
    "candidate_score_v2_features",
]


def build_summary(feature_table_shape: tuple[int, int], top_genes: str) -> str:
    """
    Build a plain-text summary for the generated feature table.

    Args:
        feature_table_shape: Row and column count for the full feature table.
        top_genes: Text rendering of the top-ranked gene rows.

    Returns:
        Summary text ready to write to disk.
    """
    rows, columns = feature_table_shape
    return (
        "DIP-AI Target Feature Table v2 Summary\n"
        "======================================\n"
        f"Output file: {OUTPUT_FILE}\n"
        f"Rows: {rows}\n"
        f"Columns: {columns}\n"
        "\nTop 30 genes by candidate_score_v2_features:\n"
        f"{top_genes}\n"
    )


def main() -> None:
    """Load, validate, build, save, and print the target feature table."""
    rna, mutations, clinical = load_all_data()
    validate_all_data(rna, mutations, clinical)

    feature_table = build_target_feature_table(mutations=mutations, rna=rna)
    feature_table.to_csv(OUTPUT_FILE, index=False)

    top_30 = feature_table.loc[:, TOP_COLUMNS].head(30)
    top_30_text = top_30.to_string(index=False)

    SUMMARY_FILE.write_text(
        build_summary(feature_table.shape, top_30_text),
        encoding="utf-8",
    )

    print("Target feature table built successfully.")
    print(f"Saved feature table: {OUTPUT_FILE}")
    print(f"Saved summary: {SUMMARY_FILE}")
    print("\nTop 30 genes:")
    print(top_30_text)


if __name__ == "__main__":
    main()
