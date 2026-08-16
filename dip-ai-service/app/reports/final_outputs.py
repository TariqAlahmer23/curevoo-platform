"""Presentation-ready final outputs for DIP-AI target rankings."""

from pathlib import Path
from typing import Any

import pandas as pd


REQUIRED_V6_COLUMNS = [
    "gene_name",
    "ranking_score_v4",
    "priority_v4",
    "evidence_tier_v6",
    "target_category_v6",
    "safety_score",
    "safety_risk",
    "normal_lung_tpm",
    "explanation_v4",
    "evidence_tier_explanation_v6",
]

TOP_TARGET_COLUMNS = [
    "rank",
    "gene_name",
    "ranking_score_v4",
    "priority_v4",
    "evidence_tier_v6",
    "target_category_v6",
    "safety_score",
    "safety_risk",
    "normal_lung_tpm",
    "evidence_tier_explanation_v6",
    "explanation_v4",
]


def _dataframe_to_markdown_table(df: pd.DataFrame) -> str:
    """
    Render a dataframe as a GitHub-style Markdown table without optional deps.

    Args:
        df: Dataframe to render.

    Returns:
        Markdown table string.
    """
    columns = [str(column) for column in df.columns]
    rows = df.fillna("").astype(str).values.tolist()
    header = "| " + " | ".join(columns) + " |"
    separator = "| " + " | ".join(["---"] * len(columns)) + " |"
    body = ["| " + " | ".join(row) + " |" for row in rows]

    return "\n".join([header, separator, *body])


def load_v6_results(path: Path) -> pd.DataFrame:
    """
    Load and validate the V6 evidence tier ranking table.

    Args:
        path: Path to ``target_ranking_v6_evidence_tiers.csv``.

    Returns:
        Validated V6 ranking dataframe.
    """
    if not path.exists():
        raise FileNotFoundError(f"V6 results file not found: {path}")

    df = pd.read_csv(path)
    missing_columns = [column for column in REQUIRED_V6_COLUMNS if column not in df.columns]
    if missing_columns:
        raise ValueError(f"V6 results missing required columns: {missing_columns}")

    return df


def create_top_targets_table(df: pd.DataFrame, top_n: int = 50) -> pd.DataFrame:
    """
    Create a clean top-targets table for presentation and review.

    Args:
        df: V6 ranking dataframe.
        top_n: Number of top targets to include.

    Returns:
        Presentation-ready top-targets dataframe.
    """
    top_targets = (
        df.sort_values("ranking_score_v4", ascending=False)
        .head(top_n)
        .reset_index(drop=True)
        .copy()
    )
    top_targets.insert(0, "rank", range(1, len(top_targets) + 1))

    return top_targets.loc[:, TOP_TARGET_COLUMNS]


def create_tier_summary(df: pd.DataFrame) -> pd.DataFrame:
    """
    Count targets by V6 evidence tier.

    Args:
        df: V6 ranking dataframe.

    Returns:
        Dataframe with evidence tier counts.
    """
    return (
        df["evidence_tier_v6"]
        .value_counts()
        .rename_axis("evidence_tier_v6")
        .reset_index(name="target_count")
    )


def create_category_summary(df: pd.DataFrame) -> pd.DataFrame:
    """
    Count targets by V6 target category.

    Args:
        df: V6 ranking dataframe.

    Returns:
        Dataframe with target category counts.
    """
    return (
        df["target_category_v6"]
        .value_counts()
        .rename_axis("target_category_v6")
        .reset_index(name="target_count")
    )


def create_dashboard_json(df: pd.DataFrame, top_n: int = 25) -> dict[str, Any]:
    """
    Create a JSON-serializable dashboard payload from V6 rankings.

    Args:
        df: V6 ranking dataframe.
        top_n: Number of top targets to include in the payload.

    Returns:
        Dashboard-ready dictionary.
    """
    priority_counts = df["priority_v4"].value_counts()
    top_targets = create_top_targets_table(df, top_n=top_n)

    return {
        "total_targets": int(len(df)),
        "high_priority_count": int(priority_counts.get("High", 0)),
        "medium_priority_count": int(priority_counts.get("Medium", 0)),
        "low_priority_count": int(priority_counts.get("Low", 0)),
        "evidence_tier_counts": {
            str(row["evidence_tier_v6"]): int(row["target_count"])
            for _, row in create_tier_summary(df).iterrows()
        },
        "target_category_counts": {
            str(row["target_category_v6"]): int(row["target_count"])
            for _, row in create_category_summary(df).iterrows()
        },
        "top_targets": [
            {
                "gene_name": str(row["gene_name"]),
                "score": float(row["ranking_score_v4"]),
                "priority": str(row["priority_v4"]),
                "evidence_tier": str(row["evidence_tier_v6"]),
                "category": str(row["target_category_v6"]),
                "safety_score": float(row["safety_score"]),
                "safety_risk": str(row["safety_risk"]),
                "explanation": str(row["evidence_tier_explanation_v6"]),
            }
            for _, row in top_targets.iterrows()
        ],
    }


def create_markdown_report(df: pd.DataFrame, output_path: Path, top_n: int = 20) -> Path:
    """
    Generate a Markdown report for presentation and committee review.

    Args:
        df: V6 ranking dataframe.
        output_path: Path where the Markdown report should be written.
        top_n: Number of top targets to include in the report table.

    Returns:
        Path to the written Markdown report.
    """
    priority_counts = df["priority_v4"].value_counts()
    tier_summary = create_tier_summary(df)
    category_summary = create_category_summary(df)
    top_targets = create_top_targets_table(df, top_n=top_n)

    report = (
        "# DIP-AI Target Ranking Report\n\n"
        "**Disclaimer:** Research use only. This report is not intended for diagnosis, "
        "treatment selection, or clinical decision-making.\n\n"
        "## Overview\n\n"
        f"- Total targets: {len(df)}\n"
        f"- High priority: {priority_counts.get('High', 0)}\n"
        f"- Medium priority: {priority_counts.get('Medium', 0)}\n"
        f"- Low priority: {priority_counts.get('Low', 0)}\n\n"
        "## Evidence Tier Summary\n\n"
        f"{_dataframe_to_markdown_table(tier_summary)}\n\n"
        "## Target Category Summary\n\n"
        f"{_dataframe_to_markdown_table(category_summary)}\n\n"
        f"## Top {top_n} Targets\n\n"
        f"{_dataframe_to_markdown_table(top_targets)}\n\n"
        "## Interpretation\n\n"
        "The top-ranked targets combine mutation burden, RNA expression, predicted "
        "protein impact, LUAD/NSCLC relevance, clinical targetability, exploratory "
        "dormancy evidence, and GTEx Lung safety context. Higher tiers should be "
        "treated as stronger research candidates, while safety-caution and "
        "passenger-like labels should be reviewed before prioritization.\n"
    )

    output_path.write_text(report, encoding="utf-8")

    return output_path
