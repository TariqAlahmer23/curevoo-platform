"""Combined target feature table construction."""

import pandas as pd

from app.features.expression_features import build_expression_features
from app.features.mutation_features import build_mutation_features


EXPRESSION_FEATURE_COLUMNS = [
    "mean_tumor_expression",
    "median_tumor_expression",
    "max_tumor_expression",
    "expression_detected_samples",
    "expression_detection_rate",
    "expression_percentile_score",
]


def build_target_feature_table(mutations: pd.DataFrame, rna: pd.DataFrame) -> pd.DataFrame:
    """
    Build the combined target feature table used for candidate scoring.

    Args:
        mutations: Cleaned mutation dataframe.
        rna: RNA expression matrix.

    Returns:
        Gene-level feature table sorted by ``candidate_score_v2_features``.
    """
    mutation_features = build_mutation_features(mutations)
    expression_features = build_expression_features(rna)

    target_features = mutation_features.merge(
        expression_features,
        on="gene_name",
        how="left",
    )
    target_features[EXPRESSION_FEATURE_COLUMNS] = target_features[
        EXPRESSION_FEATURE_COLUMNS
    ].fillna(0)

    max_mutated_patients = target_features["mutated_patients"].max()
    if max_mutated_patients > 0:
        target_features["mutation_frequency_score"] = (
            target_features["mutated_patients"] / max_mutated_patients
        )
    else:
        target_features["mutation_frequency_score"] = 0.0

    target_features["expression_score"] = target_features[
        "expression_percentile_score"
    ].fillna(0)
    target_features["protein_impact_score"] = (
        target_features["nonsynonymous_mutation_count"]
        / target_features["mutation_count"].replace(0, pd.NA)
    ).fillna(0)
    target_features["candidate_score_v2_features"] = (
        0.4 * target_features["mutation_frequency_score"]
        + 0.3 * target_features["expression_score"]
        + 0.3 * target_features["protein_impact_score"]
    )

    return target_features.sort_values(
        "candidate_score_v2_features", ascending=False
    ).reset_index(drop=True)
