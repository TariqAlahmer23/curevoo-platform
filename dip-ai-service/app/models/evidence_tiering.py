"""Evidence tiering for DIP-AI ranked target outputs."""

import pandas as pd


def assign_evidence_tier(row: pd.Series) -> str:
    """
    Assign an interpretable research evidence tier to a ranked target row.

    Args:
        row: A row from the V4 ranked target dataframe.

    Returns:
        Evidence tier label.
    """
    if row.get("passenger_penalty", 0) > 0:
        return "Tier_4_Passenger_Background_Like"
    if (
        row.get("ranking_score_v4", 0) >= 0.70
        and row.get("luad_relevance_score", 0) >= 1.0
        and row.get("passenger_penalty", 0) == 0
        and row.get("safety_score", 0) >= 0.45
    ):
        return "Tier_1_Strong_Research_Target"
    if (
        row.get("targetability_score", 0) >= 1.0
        and row.get("luad_relevance_score", 0) >= 1.0
        and row.get("ranking_score_v4", 0) >= 0.50
        and row.get("safety_score", 0) < 0.75
    ):
        return "Tier_2_Actionable_With_Safety_Caution"
    if (
        row.get("dormancy_evidence_score", 0) >= 1.0
        and row.get("ranking_score_v4", 0) >= 0.40
        and row.get("passenger_penalty", 0) == 0
    ):
        return "Tier_3_Dormancy_Exploratory_Target"

    return "Tier_5_Low_Evidence_Target"


def assign_target_category(row: pd.Series) -> str:
    """
    Assign a broad biological or translational target category.

    Args:
        row: A row from the V4 ranked target dataframe.

    Returns:
        Target category label.
    """
    if row.get("passenger_penalty", 0) > 0:
        return "Passenger-like / Background Mutation"
    if row.get("targetability_score", 0) >= 1.0:
        return "Clinically Actionable / Targetable"
    if row.get("luad_relevance_score", 0) >= 1.0:
        return "Driver / LUAD Relevant"
    if row.get("dormancy_evidence_score", 0) >= 1.0:
        return "Dormancy / Residual Exploratory"

    return "General Candidate"


def explain_evidence_tier(row: pd.Series) -> str:
    """
    Explain the assigned evidence tier in report-friendly language.

    Args:
        row: A row with an ``evidence_tier`` value.

    Returns:
        Short evidence tier explanation.
    """
    evidence_tier = row.get("evidence_tier")
    explanations = {
        "Tier_1_Strong_Research_Target": (
            "Strong integrated mutation, expression, LUAD relevance, and safety evidence"
        ),
        "Tier_2_Actionable_With_Safety_Caution": (
            "Actionable or targetable, but safety needs medical review"
        ),
        "Tier_3_Dormancy_Exploratory_Target": (
            "Exploratory dormancy or residual disease relevance, not a final clinical target"
        ),
        "Tier_4_Passenger_Background_Like": (
            "Penalized due to passenger or background-like behavior"
        ),
        "Tier_5_Low_Evidence_Target": "Insufficient integrated evidence",
    }

    return explanations.get(str(evidence_tier), "Insufficient integrated evidence")


def add_evidence_tiers(ranked: pd.DataFrame) -> pd.DataFrame:
    """
    Add evidence tiers, target categories, and tier explanations.

    Args:
        ranked: V4 ranked target dataframe.

    Returns:
        Copy of the dataframe with evidence tier columns added.
    """
    tiered = ranked.copy()
    tiered["evidence_tier"] = tiered.apply(assign_evidence_tier, axis=1)
    tiered["target_category"] = tiered.apply(assign_target_category, axis=1)
    tiered["evidence_tier_explanation"] = tiered.apply(
        explain_evidence_tier, axis=1
    )

    return tiered


def assign_evidence_tier_v6(row: pd.Series) -> str:
    """
    Assign a corrected V6 research evidence tier to a ranked target row.

    Args:
        row: A row from the V4 ranked target dataframe.

    Returns:
        V6 evidence tier label.
    """
    if row.get("passenger_penalty", 0) > 0:
        return "Tier_4_Passenger_Background_Like"
    if (
        row.get("ranking_score_v4", 0) >= 0.70
        and row.get("luad_relevance_score", 0) >= 1.0
        and row.get("passenger_penalty", 0) == 0
        and row.get("safety_score", 0) >= 0.45
    ):
        return "Tier_1_Strong_Integrated_Target"
    if (
        row.get("targetability_score", 0) >= 1.0
        and row.get("luad_relevance_score", 0) >= 1.0
        and row.get("ranking_score_v4", 0) >= 0.50
        and row.get("safety_score", 0) >= 0.75
    ):
        return "Tier_2_Actionable_Safety_Supported"
    if (
        row.get("targetability_score", 0) >= 1.0
        and row.get("luad_relevance_score", 0) >= 1.0
        and row.get("ranking_score_v4", 0) >= 0.50
        and row.get("safety_score", 0) < 0.75
    ):
        return "Tier_2_Actionable_With_Safety_Caution"
    if (
        row.get("luad_relevance_score", 0) >= 1.0
        and row.get("ranking_score_v4", 0) >= 0.50
        and row.get("passenger_penalty", 0) == 0
    ):
        return "Tier_3_LUAD_Driver_Moderate_Evidence"
    if (
        row.get("dormancy_evidence_score", 0) >= 1.0
        and row.get("ranking_score_v4", 0) >= 0.40
        and row.get("passenger_penalty", 0) == 0
    ):
        return "Tier_3_Dormancy_Exploratory_Target"

    return "Tier_5_Low_Evidence_Target"


def assign_target_category_v6(row: pd.Series) -> str:
    """
    Assign a corrected V6 target category.

    Args:
        row: A row from the V4 ranked target dataframe.

    Returns:
        V6 target category label.
    """
    if row.get("passenger_penalty", 0) > 0:
        return "Passenger-like / Background Mutation"
    if row.get("targetability_score", 0) >= 1.0 and row.get("safety_score", 0) >= 0.75:
        return "Clinically Actionable / Safety Supported"
    if row.get("targetability_score", 0) >= 1.0 and row.get("safety_score", 0) < 0.75:
        return "Clinically Actionable / Safety Caution"
    if row.get("luad_relevance_score", 0) >= 1.0:
        return "Driver / LUAD Relevant"
    if row.get("dormancy_evidence_score", 0) >= 1.0:
        return "Dormancy / Residual Exploratory"

    return "General Candidate"


def explain_evidence_tier_v6(row: pd.Series) -> str:
    """
    Explain the assigned V6 evidence tier in report-friendly language.

    Args:
        row: A row with an ``evidence_tier_v6`` value.

    Returns:
        Short V6 evidence tier explanation.
    """
    evidence_tier = row.get("evidence_tier_v6")
    explanations = {
        "Tier_1_Strong_Integrated_Target": (
            "Strong integrated evidence from LUAD relevance, mutation/expression/"
            "protein-impact, and acceptable safety"
        ),
        "Tier_2_Actionable_Safety_Supported": (
            "Clinically actionable LUAD target with low or moderate normal lung expression"
        ),
        "Tier_2_Actionable_With_Safety_Caution": (
            "Clinically actionable LUAD target, but normal lung expression requires safety review"
        ),
        "Tier_3_LUAD_Driver_Moderate_Evidence": (
            "LUAD-relevant driver with moderate evidence but not high enough for Tier 1"
        ),
        "Tier_3_Dormancy_Exploratory_Target": (
            "Exploratory dormancy/residual disease relevance; research-use only"
        ),
        "Tier_4_Passenger_Background_Like": (
            "Penalized because it behaves like a passenger/high-background mutation gene"
        ),
        "Tier_5_Low_Evidence_Target": "Insufficient integrated evidence",
    }

    return explanations.get(str(evidence_tier), "Insufficient integrated evidence")


def add_evidence_tiers_v6(ranked: pd.DataFrame) -> pd.DataFrame:
    """
    Add V6 evidence tiers, target categories, and tier explanations.

    Args:
        ranked: V4 ranked target dataframe.

    Returns:
        Copy of the dataframe with V6 evidence tier columns added.
    """
    tiered = ranked.copy()
    tiered["evidence_tier_v6"] = tiered.apply(assign_evidence_tier_v6, axis=1)
    tiered["target_category_v6"] = tiered.apply(assign_target_category_v6, axis=1)
    tiered["evidence_tier_explanation_v6"] = tiered.apply(
        explain_evidence_tier_v6, axis=1
    )

    return tiered
