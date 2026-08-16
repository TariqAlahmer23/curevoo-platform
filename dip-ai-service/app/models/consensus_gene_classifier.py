"""Raw-feature classifiers for NCG+CIViC consensus external labels."""

from __future__ import annotations

from typing import Any

import pandas as pd

from app.models.leakage_minimized_classifier import (
    ALLOWED_FEATURES,
    FEATURE_IMPORTANCE_COLUMNS as BASE_FEATURE_IMPORTANCE_COLUMNS,
    FORBIDDEN_FEATURES,
    METRIC_COLUMNS as BASE_METRIC_COLUMNS,
    PREDICTION_COLUMNS as BASE_PREDICTION_COLUMNS,
    train_evaluate_leakage_minimized_classifier,
)


CONSENSUS_FEATURES = ALLOWED_FEATURES.copy()
LABEL_COLUMN = "external_label"
LABEL_MODES = {"any_source", "high_confidence"}

METRIC_COLUMNS = ["label_mode", *BASE_METRIC_COLUMNS]
PREDICTION_COLUMNS = ["label_mode", *BASE_PREDICTION_COLUMNS]
FEATURE_IMPORTANCE_COLUMNS = [
    "label_mode",
    *BASE_FEATURE_IMPORTANCE_COLUMNS,
]


def build_consensus_classifier_dataset(
    target_features: pd.DataFrame,
    gtex_safety_features: pd.DataFrame,
    consensus_labels: pd.DataFrame,
    label_mode: str,
    negative_ratio: int = 2,
    random_state: int = 42,
) -> pd.DataFrame:
    """Build an any-source or high-confidence raw-feature dataset."""
    _validate_label_mode(label_mode)
    if not isinstance(negative_ratio, int) or isinstance(negative_ratio, bool):
        raise ValueError("negative_ratio must be a positive integer.")
    if negative_ratio <= 0:
        raise ValueError("negative_ratio must be greater than zero.")

    target_columns = ["gene_name", *CONSENSUS_FEATURES[:-1]]
    gtex_columns = ["gene_name", "normal_lung_tpm"]
    consensus_columns = [
        "gene_name",
        "consensus_label",
        "high_confidence_label",
        "consensus_confidence",
    ]
    _require_columns(target_features, target_columns, "target_features")
    _require_columns(gtex_safety_features, gtex_columns, "gtex_safety_features")
    _require_columns(consensus_labels, consensus_columns, "consensus_labels")

    targets = _prepare_unique_gene_table(
        target_features.loc[:, target_columns],
        "target_features",
    )
    consensus = _prepare_unique_gene_table(
        consensus_labels.loc[:, consensus_columns],
        "consensus_labels",
    )

    gtex = gtex_safety_features.loc[:, gtex_columns].copy()
    gtex["gene_name"] = _normalize_gene_names(gtex["gene_name"])
    gtex["normal_lung_tpm"] = pd.to_numeric(
        gtex["normal_lung_tpm"],
        errors="coerce",
    )
    gtex = gtex.dropna(subset=["gene_name"])
    gtex = (
        gtex.groupby("gene_name", as_index=False)["normal_lung_tpm"]
        .median()
    )

    universe = targets.merge(
        gtex,
        on="gene_name",
        how="left",
        validate="one_to_one",
    )
    universe = universe.merge(
        consensus,
        on="gene_name",
        how="left",
        validate="one_to_one",
    )
    if universe["consensus_label"].isna().any():
        missing_count = int(universe["consensus_label"].isna().sum())
        raise ValueError(
            f"Consensus labels are missing for {missing_count} target genes."
        )

    if label_mode == "any_source":
        positive_mask = pd.to_numeric(
            universe["consensus_label"],
            errors="coerce",
        ).eq(1)
    else:
        positive_mask = pd.to_numeric(
            universe["high_confidence_label"],
            errors="coerce",
        ).eq(1)

    negative_mask = pd.to_numeric(
        universe["high_confidence_label"],
        errors="coerce",
    ).eq(0)
    positives = universe.loc[positive_mask].copy()
    negative_pool = universe.loc[negative_mask].copy()
    maximum_negatives = negative_ratio * len(positives)
    if len(negative_pool) > maximum_negatives:
        negatives = negative_pool.sample(
            n=maximum_negatives,
            random_state=random_state,
        ).copy()
    else:
        negatives = negative_pool.copy()

    positives[LABEL_COLUMN] = 1
    positives["label_source"] = positives["consensus_confidence"]
    negatives[LABEL_COLUMN] = 0
    negatives["label_source"] = "negative_candidate"

    dataset = pd.concat([positives, negatives], ignore_index=True)
    for feature in CONSENSUS_FEATURES:
        dataset[feature] = pd.to_numeric(dataset[feature], errors="coerce")
    dataset[LABEL_COLUMN] = dataset[LABEL_COLUMN].astype(int)
    dataset["label_mode"] = label_mode

    return dataset.loc[
        :,
        [
            "gene_name",
            *CONSENSUS_FEATURES,
            LABEL_COLUMN,
            "label_source",
            "label_mode",
        ],
    ].sort_values(
        [LABEL_COLUMN, "gene_name"],
        ascending=[False, True],
    ).reset_index(drop=True)


def train_evaluate_consensus_classifier(
    dataset: pd.DataFrame,
    feature_columns: list[str],
    label_mode: str,
) -> dict[str, Any]:
    """Evaluate one consensus label mode with leakage-minimized models."""
    _validate_label_mode(label_mode)
    if "label_mode" in dataset.columns:
        dataset_modes = set(dataset["label_mode"].dropna().astype(str))
        if dataset_modes and dataset_modes != {label_mode}:
            raise ValueError(
                f"Dataset label_mode values {dataset_modes} do not match "
                f"requested mode '{label_mode}'."
            )

    result = train_evaluate_leakage_minimized_classifier(
        dataset=dataset,
        feature_columns=feature_columns,
    )
    result["label_mode"] = label_mode
    for key in ["metrics", "predictions", "feature_importance"]:
        for row in result.get(key, []):
            row["label_mode"] = label_mode
    return result


def metrics_to_dataframe(result: dict[str, Any]) -> pd.DataFrame:
    """Convert consensus metrics to a stable CSV-ready dataframe."""
    rows = result.get("metrics", [])
    if rows:
        return pd.DataFrame(rows).reindex(columns=METRIC_COLUMNS)

    summary = result.get("label_summary", {})
    return pd.DataFrame(
        [
            {
                "label_mode": result.get("label_mode", ""),
                "model_name": "ALL",
                "status": result.get("status", "SKIPPED"),
                "evaluation_strategy": result.get("evaluation_strategy"),
                "n_genes": summary.get("n_genes", 0),
                "positive_genes": summary.get("positive_genes", 0),
                "negative_genes": summary.get("negative_genes", 0),
                "warning": " | ".join(result.get("warnings", [])),
            }
        ],
        columns=METRIC_COLUMNS,
    )


def predictions_to_dataframe(result: dict[str, Any]) -> pd.DataFrame:
    """Convert consensus out-of-fold predictions to a dataframe."""
    return pd.DataFrame(result.get("predictions", [])).reindex(
        columns=PREDICTION_COLUMNS
    )


def feature_importance_to_dataframe(
    result: dict[str, Any],
) -> pd.DataFrame:
    """Convert consensus feature importances to a dataframe."""
    return pd.DataFrame(result.get("feature_importance", [])).reindex(
        columns=FEATURE_IMPORTANCE_COLUMNS
    )


def _validate_label_mode(label_mode: str) -> None:
    if label_mode not in LABEL_MODES:
        raise ValueError(
            f"label_mode must be one of {sorted(LABEL_MODES)}; "
            f"received: {label_mode!r}"
        )


def _prepare_unique_gene_table(
    dataframe: pd.DataFrame,
    dataframe_name: str,
) -> pd.DataFrame:
    prepared = dataframe.copy()
    prepared["gene_name"] = _normalize_gene_names(prepared["gene_name"])
    prepared = prepared.dropna(subset=["gene_name"])
    duplicate_mask = prepared["gene_name"].duplicated(keep=False)
    if duplicate_mask.any():
        examples = sorted(
            prepared.loc[duplicate_mask, "gene_name"].unique()
        )[:5]
        raise ValueError(
            f"{dataframe_name} contains duplicate normalized gene names; "
            f"examples: {examples}"
        )
    return prepared


def _normalize_gene_names(values: pd.Series) -> pd.Series:
    normalized = values.astype("string").str.strip().str.upper()
    return normalized.mask(normalized.eq(""), pd.NA)


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
