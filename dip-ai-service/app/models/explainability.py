"""Explainability helpers for target ranking outputs."""

import pandas as pd


def explain_ranking_v3(row: pd.Series) -> str:
    """
    Generate a concise explanation for a ranked V3 target row.

    Args:
        row: A row from the ranked target dataframe.

    Returns:
        Human-readable explanation of the main ranking signals.
    """
    reasons: list[str] = []

    if row.get("luad_relevance_score", 0) >= 1.0:
        reasons.append("Known LUAD/NSCLC relevant gene")
    if row.get("targetability_score", 0) >= 1.0:
        reasons.append("Clinically targetable/actionable gene")
    if row.get("mutation_frequency_score", 0) > 0.5:
        reasons.append("Frequently mutated across patients")
    if row.get("expression_score", 0) > 0.8:
        reasons.append("High tumor RNA expression")
    if row.get("protein_impact_score", 0) > 0.8:
        reasons.append("High protein-impact mutation ratio")
    if row.get("dormancy_evidence_score", 0) >= 1.0:
        reasons.append("Exploratory dormancy/residual disease association")
    if row.get("passenger_penalty", 0) > 0:
        reasons.append(
            "Penalty applied because this gene is commonly high-background/passenger-like"
        )

    if not reasons:
        return "Ranked from integrated mutation, expression, and protein-impact evidence"

    return "; ".join(reasons)


def add_ranking_explanations_v3(ranked: pd.DataFrame) -> pd.DataFrame:
    """
    Add V3 ranking explanations to a ranked target dataframe.

    Args:
        ranked: Output from ``rank_targets_v3``.

    Returns:
        Copy of ranked dataframe with an ``explanation_v3`` column.
    """
    explained = ranked.copy()
    explained["explanation_v3"] = explained.apply(explain_ranking_v3, axis=1)

    return explained


def explain_ranking_v4(row: pd.Series) -> str:
    """
    Generate a V4 explanation combining V3 evidence and GTEx Lung safety context.

    Args:
        row: A row from the V4 ranked target dataframe.

    Returns:
        Human-readable V4 explanation.
    """
    explanation_parts: list[str] = []
    explanation_v3 = row.get("explanation_v3")
    if pd.notna(explanation_v3) and str(explanation_v3).strip():
        explanation_parts.append(str(explanation_v3).strip())

    safety_risk = row.get("safety_risk", "Unknown")
    safety_score = row.get("safety_score")

    if safety_risk == "Unknown" or pd.isna(safety_score):
        explanation_parts.append("GTEx Lung safety data unavailable")
    elif safety_score >= 0.9:
        explanation_parts.append("Low normal lung expression supports safety priority")
    elif 0.7 <= safety_score < 0.9:
        explanation_parts.append(
            "Moderate normal lung expression; safety acceptable but should be reviewed"
        )
    elif 0.4 <= safety_score < 0.7:
        explanation_parts.append("High normal lung expression; safety caution applied")
    else:
        explanation_parts.append(
            "Very high normal lung expression; strong safety penalty applied"
        )

    return "; ".join(explanation_parts)


def add_ranking_explanations_v4(ranked: pd.DataFrame) -> pd.DataFrame:
    """
    Add V4 ranking explanations to a ranked target dataframe.

    Args:
        ranked: Output from ``rank_targets_v4_with_safety``.

    Returns:
        Copy of ranked dataframe with an ``explanation_v4`` column.
    """
    explained = ranked.copy()
    explained["explanation_v4"] = explained.apply(explain_ranking_v4, axis=1)

    return explained
