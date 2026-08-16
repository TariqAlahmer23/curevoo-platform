"""Build small mutation and RNA expression CSVs for testing ``POST /analyze``.

The samples are real slices of the processed cohort, not synthetic data. Genes
are selected by how many patients carry a mutation, so the resulting upload
exercises the full ranking, safety, tiering, and external-evidence path while
staying small enough to upload from a browser.
"""

from pathlib import Path
import sys

import pandas as pd

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import DATA_DIR, MUTATIONS_FILE, RNA_FILE


SAMPLES_DIR = DATA_DIR / "samples"
MUTATIONS_SAMPLE_FILE = SAMPLES_DIR / "sample_mutations.csv"
EXPRESSION_SAMPLE_FILE = SAMPLES_DIR / "sample_rna_expression.csv"

# Columns the feature layer needs from a mutation table.
MUTATION_COLUMNS = [
    "Hugo_Symbol",
    "Variant_Classification",
    "Tumor_Sample_Barcode",
    "patient_barcode",
    "sample_barcode",
]

GENE_COUNT = 400
SAMPLE_COLUMN_COUNT = 120
RNA_CHUNK_ROWS = 20_000


def select_sample_genes(mutations: pd.DataFrame, gene_count: int) -> list[str]:
    """
    Select the most recurrently mutated genes in the cohort.

    Args:
        mutations: Full cohort mutation table.
        gene_count: Number of genes to keep.

    Returns:
        Gene symbols ordered by number of mutated patients.
    """
    recurrence = (
        mutations.groupby("Hugo_Symbol")["patient_barcode"]
        .nunique()
        .sort_values(ascending=False)
    )

    return recurrence.head(gene_count).index.tolist()


def load_expression_for_genes(
    rna_path: Path, genes: set[str], sample_column_count: int
) -> pd.DataFrame:
    """
    Read expression rows for the selected genes without loading the full matrix.

    Args:
        rna_path: Path to the cohort RNA expression matrix.
        genes: Gene symbols to keep.
        sample_column_count: Number of tumour sample columns to keep.

    Returns:
        Expression matrix limited to the selected genes and samples.
    """
    matched_chunks: list[pd.DataFrame] = []
    columns: list[str] | None = None

    for chunk in pd.read_csv(rna_path, chunksize=RNA_CHUNK_ROWS, low_memory=False):
        if columns is None:
            sample_columns = [
                column for column in chunk.columns if column != "gene_name"
            ]
            columns = ["gene_name", *sample_columns[:sample_column_count]]

        matched = chunk.loc[chunk["gene_name"].isin(genes), columns]
        if not matched.empty:
            matched_chunks.append(matched)

    if not matched_chunks:
        raise ValueError("No expression rows matched the selected genes.")

    return pd.concat(matched_chunks, ignore_index=True).drop_duplicates(
        subset=["gene_name"]
    )


def main() -> None:
    """Build and save the sample upload datasets."""
    if not MUTATIONS_FILE.exists():
        raise FileNotFoundError(f"Required mutation file not found: {MUTATIONS_FILE}")
    if not RNA_FILE.exists():
        raise FileNotFoundError(f"Required RNA file not found: {RNA_FILE}")

    SAMPLES_DIR.mkdir(parents=True, exist_ok=True)

    mutations = pd.read_csv(
        MUTATIONS_FILE, usecols=MUTATION_COLUMNS, low_memory=False
    ).dropna(subset=["Hugo_Symbol"])

    genes = select_sample_genes(mutations, GENE_COUNT)
    mutations_sample = mutations.loc[mutations["Hugo_Symbol"].isin(genes)].reset_index(
        drop=True
    )
    expression_sample = load_expression_for_genes(
        RNA_FILE, set(genes), SAMPLE_COLUMN_COUNT
    )

    mutations_sample.to_csv(MUTATIONS_SAMPLE_FILE, index=False)
    expression_sample.to_csv(EXPRESSION_SAMPLE_FILE, index=False)

    print("Sample upload datasets built successfully.")
    print(f"Saved mutations: {MUTATIONS_SAMPLE_FILE}")
    print(f"  rows: {len(mutations_sample)}, genes: {mutations_sample['Hugo_Symbol'].nunique()}")
    print(f"Saved expression: {EXPRESSION_SAMPLE_FILE}")
    print(
        f"  genes: {len(expression_sample)}, "
        f"samples: {len(expression_sample.columns) - 1}"
    )


if __name__ == "__main__":
    main()
