"""Target ranking models for DIP-AI."""

import pandas as pd

from app.models.gene_knowledge_base import (
    get_dormancy_evidence_score,
    get_luad_relevance_score,
    get_passenger_penalty,
    get_targetability_score,
)


REQUIRED_V3_FEATURE_COLUMNS = [
    "gene_name",
    "mutation_frequency_score",
    "expression_score",
    "protein_impact_score",
]

REQUIRED_V4_RANKING_COLUMNS = [
    "gene_name",
    "ranking_score_v3",
]

REQUIRED_SAFETY_COLUMNS = [
    "gene_name",
    "normal_lung_tpm",
    "safety_score",
    "safety_risk",
    "safety_note",
]


def _assign_priority_v3(score: float) -> str:
    """Assign a V3 priority label from a clipped ranking score."""
    if score >= 0.70:
        return "High"
    if score >= 0.40:
        return "Medium"

    return "Low"


def _assign_priority_v4(score: float) -> str:
    """Assign a V4 priority label from a clipped ranking score."""
    if score >= 0.70:
        return "High"
    if score >= 0.40:
        return "Medium"

    return "Low"


def rank_targets_v3(features: pd.DataFrame) -> pd.DataFrame:
    """
    Rank gene targets using V2 engineered features and curated V3 biology priors.

    Args:
        features: Gene-level feature table produced by the V2 feature layer.

    Returns:
        Ranked dataframe sorted by ``ranking_score_v3`` in descending order.
    """
    missing_columns = [
        column for column in REQUIRED_V3_FEATURE_COLUMNS if column not in features.columns
    ]
    if missing_columns:
        raise ValueError(f"Feature dataframe missing required columns: {missing_columns}")

    ranked = features.copy()
    ranked["luad_relevance_score"] = ranked["gene_name"].apply(
        get_luad_relevance_score
    )
    ranked["passenger_penalty"] = ranked["gene_name"].apply(get_passenger_penalty)
    ranked["targetability_score"] = ranked["gene_name"].apply(get_targetability_score)
    ranked["dormancy_evidence_score"] = ranked["gene_name"].apply(
        get_dormancy_evidence_score
    )

    ranked["ranking_score_v3"] = (
        0.25 * ranked["mutation_frequency_score"].fillna(0)
        + 0.20 * ranked["expression_score"].fillna(0)
        + 0.20 * ranked["protein_impact_score"].fillna(0)
        + 0.20 * ranked["luad_relevance_score"]
        + 0.10 * ranked["targetability_score"]
        + 0.05 * ranked["dormancy_evidence_score"]
        - ranked["passenger_penalty"]
    ).clip(lower=0, upper=1)

    ranked["priority_v3"] = ranked["ranking_score_v3"].apply(_assign_priority_v3)

    return ranked.sort_values("ranking_score_v3", ascending=False).reset_index(drop=True)


def rank_targets_v4_with_safety(
    ranked_v3: pd.DataFrame, safety_features: pd.DataFrame
) -> pd.DataFrame:
    """
    Apply GTEx Lung safety filtering to a V3 target ranking.

    Args:
        ranked_v3: V3 ranked target dataframe.
        safety_features: GTEx Lung safety feature dataframe.

    Returns:
        V4 ranked dataframe preserving V3 columns and adding safety columns.
    """
    missing_ranking_columns = [
        column for column in REQUIRED_V4_RANKING_COLUMNS if column not in ranked_v3.columns
    ]
    if missing_ranking_columns:
        raise ValueError(
            f"V3 ranking dataframe missing required columns: {missing_ranking_columns}"
        )

    missing_safety_columns = [
        column for column in REQUIRED_SAFETY_COLUMNS if column not in safety_features.columns
    ]
    if missing_safety_columns:
        raise ValueError(
            f"Safety dataframe missing required columns: {missing_safety_columns}"
        )

    ranked = ranked_v3.copy().merge(safety_features, on="gene_name", how="left")
    ranked["normal_lung_tpm"] = pd.to_numeric(
        ranked["normal_lung_tpm"], errors="coerce"
    )
    ranked["safety_score"] = ranked["safety_score"].fillna(0.50)
    ranked["safety_risk"] = ranked["safety_risk"].fillna("Unknown")
    ranked["safety_note"] = ranked["safety_note"].fillna(
        "GTEx Lung safety data not available for this gene"
    )

    ranked["safety_penalty"] = (1 - ranked["safety_score"]) * 0.20
    ranked["ranking_score_v4"] = (
        ranked["ranking_score_v3"].fillna(0) - ranked["safety_penalty"]
    ).clip(lower=0, upper=1)
    ranked["priority_v4"] = ranked["ranking_score_v4"].apply(_assign_priority_v4)

    return ranked.sort_values("ranking_score_v4", ascending=False).reset_index(drop=True)
