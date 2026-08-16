"""Build non-circular external gene labels for supervised target classification."""

from __future__ import annotations

import numpy as np
import pandas as pd


REQUIRED_RANKED_COLUMNS = [
    "gene_name",
    "luad_relevance_score",
    "targetability_score",
    "dormancy_evidence_score",
    "passenger_penalty",
]

EXTERNAL_EVIDENCE_COLUMNS = [
    "gene_name",
    "source",
    "evidence_type",
    "evidence_score",
    "label",
]


def build_external_gene_labels(
    ranked_genes: pd.DataFrame,
    external_evidence: pd.DataFrame,
) -> pd.DataFrame:
    """
    Build gene-level external labels for supervised ML classification.

    Positives come only from external evidence rows with ``label == 1``.
    Negatives are limited to genes with no positive external evidence and no
    internal uncertainty flags. Genes that are LUAD relevant, clinically
    targetable, dormancy/residual-disease related, or passenger-like are
    excluded unless they have positive external evidence.
    """
    missing_columns = [
        column for column in REQUIRED_RANKED_COLUMNS if column not in ranked_genes.columns
    ]
    if missing_columns:
        raise ValueError(f"Ranked genes missing required columns: {missing_columns}")

    ranked = ranked_genes.copy()
    ranked["gene_name"] = ranked["gene_name"].astype("string").str.strip().str.upper()
    ranked = ranked.dropna(subset=["gene_name"])
    ranked = ranked[ranked["gene_name"] != ""]

    aggregated_evidence = _aggregate_external_evidence(external_evidence)
    labeled = ranked.merge(aggregated_evidence, on="gene_name", how="left")

    labeled["external_positive_evidence_count"] = (
        labeled["external_positive_evidence_count"].fillna(0).astype(int)
    )
    labeled["external_sources"] = labeled["external_sources"].fillna("")
    labeled["max_external_evidence_score"] = labeled[
        "max_external_evidence_score"
    ].fillna(0.0)

    has_positive_external_evidence = labeled["external_positive_evidence_count"] > 0
    uncertain_for_negative = (
        (_numeric(labeled["luad_relevance_score"]) >= 1.0)
        | (_numeric(labeled["targetability_score"]) >= 1.0)
        | (_numeric(labeled["dormancy_evidence_score"]) >= 1.0)
        | (_numeric(labeled["passenger_penalty"]) > 0.0)
    )
    safe_negative = ~has_positive_external_evidence & ~uncertain_for_negative

    labeled["external_label"] = np.nan
    labeled.loc[has_positive_external_evidence, "external_label"] = 1
    labeled.loc[safe_negative, "external_label"] = 0

    labeled["external_label_status"] = "excluded_uncertain"
    labeled.loc[has_positive_external_evidence, "external_label_status"] = (
        "positive_external_evidence"
    )
    labeled.loc[safe_negative, "external_label_status"] = "clean_negative"

    labeled["external_uncertain_reason"] = ""
    labeled.loc[
        ~has_positive_external_evidence & (_numeric(labeled["luad_relevance_score"]) >= 1.0),
        "external_uncertain_reason",
    ] = _append_reason(labeled["external_uncertain_reason"], "luad_relevance")
    labeled.loc[
        ~has_positive_external_evidence & (_numeric(labeled["targetability_score"]) >= 1.0),
        "external_uncertain_reason",
    ] = _append_reason(labeled["external_uncertain_reason"], "targetability")
    labeled.loc[
        ~has_positive_external_evidence
        & (_numeric(labeled["dormancy_evidence_score"]) >= 1.0),
        "external_uncertain_reason",
    ] = _append_reason(labeled["external_uncertain_reason"], "dormancy_evidence")
    labeled.loc[
        ~has_positive_external_evidence & (_numeric(labeled["passenger_penalty"]) > 0.0),
        "external_uncertain_reason",
    ] = _append_reason(labeled["external_uncertain_reason"], "passenger_like")

    return labeled


def _aggregate_external_evidence(external_evidence: pd.DataFrame) -> pd.DataFrame:
    if external_evidence.empty:
        return pd.DataFrame(
            columns=[
                "gene_name",
                "external_positive_evidence_count",
                "external_sources",
                "max_external_evidence_score",
            ]
        )

    missing_columns = [
        column
        for column in EXTERNAL_EVIDENCE_COLUMNS
        if column not in external_evidence.columns
    ]
    if missing_columns:
        raise ValueError(
            f"External evidence missing required columns: {missing_columns}"
        )

    evidence = external_evidence.loc[:, EXTERNAL_EVIDENCE_COLUMNS].copy()
    evidence["gene_name"] = evidence["gene_name"].astype("string").str.strip().str.upper()
    evidence["source"] = evidence["source"].astype("string").str.strip()
    evidence["evidence_score"] = pd.to_numeric(
        evidence["evidence_score"], errors="coerce"
    )
    evidence["label"] = pd.to_numeric(evidence["label"], errors="coerce")
    evidence = evidence.dropna(subset=["gene_name"])
    evidence = evidence[evidence["gene_name"] != ""]
    invalid_label_mask = evidence["label"].isna() | ~evidence["label"].isin([0, 1])
    if invalid_label_mask.any():
        raise ValueError("External evidence contains missing or non-binary labels.")

    evidence["positive_label"] = (evidence["label"] == 1).astype(int)

    return (
        evidence.groupby("gene_name")
        .agg(
            external_positive_evidence_count=("positive_label", "sum"),
            external_sources=("source", _join_unique_values),
            max_external_evidence_score=("evidence_score", "max"),
        )
        .reset_index()
    )


def _join_unique_values(values: pd.Series) -> str:
    unique_values = sorted(
        str(value).strip()
        for value in values.dropna().unique()
        if str(value).strip()
    )
    return ";".join(unique_values)


def _numeric(series: pd.Series) -> pd.Series:
    return pd.to_numeric(series, errors="coerce").fillna(0.0)


def _append_reason(existing_reasons: pd.Series, reason: str) -> pd.Series:
    return existing_reasons.apply(
        lambda value: reason if not value else f"{value};{reason}"
    )
