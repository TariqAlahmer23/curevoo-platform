"""RNA expression feature engineering for target candidate scoring."""

import pandas as pd


def build_expression_features(rna: pd.DataFrame) -> pd.DataFrame:
    """
    Build gene-level expression features from a RNA expression matrix.

    Args:
        rna: RNA expression dataframe with a ``gene_name`` column and one
            column per tumor sample.

    Returns:
        Dataframe with one row per gene and expression-derived feature columns.
    """
    if "gene_name" not in rna.columns:
        raise ValueError("RNA dataframe missing required column: gene_name")

    sample_columns = [column for column in rna.columns if column != "gene_name"]
    if not sample_columns:
        raise ValueError("RNA dataframe has no sample columns.")

    expression_values = rna[sample_columns].apply(pd.to_numeric, errors="coerce")
    detected_samples = expression_values.gt(1).sum(axis=1)

    features = pd.DataFrame(
        {
            "gene_name": rna["gene_name"],
            "mean_tumor_expression": expression_values.mean(axis=1),
            "median_tumor_expression": expression_values.median(axis=1),
            "max_tumor_expression": expression_values.max(axis=1),
            "expression_detected_samples": detected_samples,
            "expression_detection_rate": detected_samples / len(sample_columns),
        }
    )
    features["expression_percentile_score"] = features[
        "mean_tumor_expression"
    ].rank(pct=True)

    return features.dropna(subset=["gene_name"]).reset_index(drop=True)
