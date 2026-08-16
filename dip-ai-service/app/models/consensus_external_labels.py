"""Build consensus external gene labels from NCG and CIViC evidence."""

from __future__ import annotations

import pandas as pd


OUTPUT_COLUMNS = [
    "gene_name",
    "in_ncg",
    "in_civic",
    "external_source_count",
    "external_sources",
    "max_external_evidence_score",
    "consensus_label",
    "consensus_confidence",
    "high_confidence_label",
]


def build_consensus_external_labels(
    ranked_genes: pd.DataFrame,
    ncg_labels: pd.DataFrame,
    civic_labels: pd.DataFrame,
) -> pd.DataFrame:
    """Build NCG-or-CIViC and NCG-and-CIViC labels for ranked genes."""
    _require_columns(ranked_genes, ["gene_name"], "ranked_genes")
    _require_columns(ncg_labels, ["gene_name"], "ncg_labels")
    _require_columns(civic_labels, ["gene_name"], "civic_labels")

    ranked = pd.DataFrame(
        {"gene_name": _normalize_gene_names(ranked_genes["gene_name"])}
    ).dropna(subset=["gene_name"])
    if ranked["gene_name"].duplicated().any():
        examples = sorted(
            ranked.loc[
                ranked["gene_name"].duplicated(keep=False),
                "gene_name",
            ].unique()
        )[:5]
        raise ValueError(
            "ranked_genes contains duplicate normalized gene names; "
            f"examples: {examples}"
        )

    ncg_scores = _positive_evidence_scores(ncg_labels, "NCG")
    civic_scores = _positive_evidence_scores(civic_labels, "CIViC")
    ncg_genes = set(ncg_scores)
    civic_genes = set(civic_scores)

    consensus = ranked.copy()
    consensus["in_ncg"] = consensus["gene_name"].isin(ncg_genes)
    consensus["in_civic"] = consensus["gene_name"].isin(civic_genes)
    consensus["external_source_count"] = (
        consensus["in_ncg"].astype(int) + consensus["in_civic"].astype(int)
    )
    consensus["external_sources"] = consensus.apply(
        lambda row: _external_sources(
            bool(row["in_ncg"]),
            bool(row["in_civic"]),
        ),
        axis=1,
    )

    ncg_evidence = consensus["gene_name"].map(ncg_scores).fillna(0.0)
    civic_evidence = consensus["gene_name"].map(civic_scores).fillna(0.0)
    consensus["max_external_evidence_score"] = pd.concat(
        [ncg_evidence, civic_evidence],
        axis=1,
    ).max(axis=1)
    consensus["consensus_label"] = (
        consensus["external_source_count"] > 0
    ).astype(int)
    consensus["consensus_confidence"] = consensus[
        "external_source_count"
    ].map(
        {
            2: "high_confidence_positive",
            1: "single_source_positive",
            0: "negative_candidate",
        }
    )
    consensus["high_confidence_label"] = pd.NA
    consensus.loc[
        consensus["external_source_count"] == 2,
        "high_confidence_label",
    ] = 1
    consensus.loc[
        consensus["external_source_count"] == 0,
        "high_confidence_label",
    ] = 0
    consensus["high_confidence_label"] = pd.to_numeric(
        consensus["high_confidence_label"],
        errors="coerce",
    ).astype("Float64")

    return consensus.loc[:, OUTPUT_COLUMNS].reset_index(drop=True)


def _positive_evidence_scores(
    labels: pd.DataFrame,
    source_name: str,
) -> dict[str, float]:
    work = labels.copy()
    work["gene_name"] = _normalize_gene_names(work["gene_name"])
    work = work.dropna(subset=["gene_name"])

    if "label" in work.columns:
        numeric_labels = pd.to_numeric(work["label"], errors="coerce")
        work = work.loc[numeric_labels.eq(1)].copy()

    if "evidence_score" in work.columns:
        work["evidence_score"] = pd.to_numeric(
            work["evidence_score"],
            errors="coerce",
        ).fillna(1.0)
    else:
        work["evidence_score"] = 1.0

    if work.empty:
        return {}
    grouped = work.groupby("gene_name")["evidence_score"].max()
    scores = {
        str(gene_name): float(score)
        for gene_name, score in grouped.items()
    }
    if not scores:
        raise ValueError(f"No positive {source_name} labels were available.")
    return scores


def _normalize_gene_names(values: pd.Series) -> pd.Series:
    normalized = values.astype("string").str.strip().str.upper()
    return normalized.mask(normalized.eq(""), pd.NA)


def _external_sources(in_ncg: bool, in_civic: bool) -> str:
    sources = []
    if in_ncg:
        sources.append("NCG")
    if in_civic:
        sources.append("CIViC")
    return ";".join(sources)


def _require_columns(
    dataframe: pd.DataFrame,
    required_columns: list[str],
    dataframe_name: str,
) -> None:
    missing = [
        column for column in required_columns if column not in dataframe.columns
    ]
    if missing:
        raise ValueError(f"{dataframe_name} missing required columns: {missing}")
