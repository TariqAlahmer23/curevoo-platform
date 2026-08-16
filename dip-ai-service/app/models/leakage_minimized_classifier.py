"""Leakage-minimized NCG classifier using raw, data-derived gene features."""

from __future__ import annotations

import warnings
from typing import Any

import numpy as np
import pandas as pd
from sklearn.base import clone
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    average_precision_score,
    balanced_accuracy_score,
    confusion_matrix,
    f1_score,
    matthews_corrcoef,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import StratifiedKFold
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler


ALLOWED_FEATURES = [
    "mutation_count",
    "mutated_patients",
    "mutated_samples",
    "nonsynonymous_mutation_count",
    "missense_count",
    "frameshift_count",
    "nonsense_count",
    "mean_tumor_expression",
    "median_tumor_expression",
    "max_tumor_expression",
    "expression_detected_samples",
    "expression_detection_rate",
    "normal_lung_tpm",
]

FORBIDDEN_FEATURES = [
    "ranking_score_v3",
    "ranking_score_v4",
    "safety_score",
    "safety_penalty",
    "priority_v4",
    "evidence_tier_v6",
    "target_category_v6",
    "luad_relevance_score",
    "targetability_score",
    "dormancy_evidence_score",
    "passenger_penalty",
    "explanation_v4",
    "evidence_tier_explanation_v6",
]

LABEL_COLUMN = "external_label"
RANDOM_STATE = 42
N_SPLITS = 5
MIN_POSITIVES = 20
MIN_NEGATIVES = 20

METRIC_COLUMNS = [
    "model_name",
    "status",
    "accuracy",
    "balanced_accuracy",
    "precision",
    "recall",
    "f1_score",
    "mcc",
    "roc_auc",
    "pr_auc",
    "tn",
    "fp",
    "fn",
    "tp",
    "evaluation_strategy",
    "n_genes",
    "positive_genes",
    "negative_genes",
    "warning",
]

PREDICTION_COLUMNS = [
    "gene_name",
    "external_label",
    "predicted_label",
    "predicted_probability",
    "model_name",
]

FEATURE_IMPORTANCE_COLUMNS = [
    "model_name",
    "feature_name",
    "importance",
]


def build_leakage_minimized_dataset(
    target_features: pd.DataFrame,
    gtex_safety_features: pd.DataFrame,
    ncg_labels: pd.DataFrame,
    negative_ratio: int = 2,
    random_state: int = 42,
) -> pd.DataFrame:
    """
    Build an NCG-vs-non-NCG dataset from raw/data-derived features only.

    All NCG genes present in the target-feature universe are retained as
    positives. Genes not present in NCG are eligible negatives, sampled up to
    ``negative_ratio`` times the number of positives. Missing numeric values
    remain missing so model pipelines can impute medians within each CV fold.
    """
    if not isinstance(negative_ratio, int) or isinstance(negative_ratio, bool):
        raise ValueError("negative_ratio must be a positive integer.")
    if negative_ratio <= 0:
        raise ValueError("negative_ratio must be greater than zero.")

    target_required = ["gene_name", *ALLOWED_FEATURES[:-1]]
    gtex_required = ["gene_name", "normal_lung_tpm"]
    _require_columns(target_features, target_required, "target_features")
    _require_columns(gtex_safety_features, gtex_required, "gtex_safety_features")
    _require_columns(ncg_labels, ["gene_name"], "ncg_labels")

    # Select columns before merging so derived scores and curated knowledge
    # cannot enter the leakage-minimized dataset accidentally.
    targets = target_features.loc[:, target_required].copy()
    gtex = gtex_safety_features.loc[:, gtex_required].copy()

    targets["gene_name"] = _normalize_gene_names(targets["gene_name"])
    gtex["gene_name"] = _normalize_gene_names(gtex["gene_name"])
    targets = targets.dropna(subset=["gene_name"])
    gtex = gtex.dropna(subset=["gene_name"])

    _raise_for_duplicate_genes(targets, "target_features")
    if gtex["gene_name"].duplicated().any():
        gtex = (
            gtex.assign(
                normal_lung_tpm=pd.to_numeric(
                    gtex["normal_lung_tpm"], errors="coerce"
                )
            )
            .groupby("gene_name", as_index=False)["normal_lung_tpm"]
            .median()
        )

    dataset_universe = targets.merge(
        gtex,
        on="gene_name",
        how="left",
        validate="one_to_one",
    )

    ncg_gene_names = set(
        _normalize_gene_names(ncg_labels["gene_name"]).dropna().astype(str)
    )
    is_ncg_positive = dataset_universe["gene_name"].isin(ncg_gene_names)

    positives = dataset_universe.loc[is_ncg_positive].copy()
    negative_pool = dataset_universe.loc[~is_ncg_positive].copy()
    max_negatives = negative_ratio * len(positives)
    if len(negative_pool) > max_negatives:
        negatives = negative_pool.sample(
            n=max_negatives,
            random_state=random_state,
        ).copy()
    else:
        negatives = negative_pool.copy()

    positives[LABEL_COLUMN] = 1
    positives["label_source"] = "NCG_positive"
    negatives[LABEL_COLUMN] = 0
    negatives["label_source"] = "non_NCG_sampled_negative"

    dataset = pd.concat([positives, negatives], ignore_index=True)
    for feature in ALLOWED_FEATURES:
        dataset[feature] = pd.to_numeric(dataset[feature], errors="coerce")

    dataset[LABEL_COLUMN] = dataset[LABEL_COLUMN].astype(int)
    dataset = dataset.loc[
        :,
        ["gene_name", *ALLOWED_FEATURES, LABEL_COLUMN, "label_source"],
    ]
    return dataset.sort_values(
        [LABEL_COLUMN, "gene_name"],
        ascending=[False, True],
    ).reset_index(drop=True)


def train_evaluate_leakage_minimized_classifier(
    dataset: pd.DataFrame,
    feature_columns: list[str],
) -> dict:
    """
    Evaluate leakage-minimized classifiers with stratified 5-fold CV.

    Predictions are out-of-fold predictions. Confusion matrices and metrics are
    computed over the combined out-of-fold predictions, which is equivalent to
    aggregating the five fold-level confusion matrices.
    """
    requested_features = list(feature_columns)
    _validate_requested_features(dataset, requested_features)

    label_summary = _label_summary(dataset)
    safety_issues = []
    if label_summary["positive_genes"] < MIN_POSITIVES:
        safety_issues.append(
            f"Insufficient NCG positives: {label_summary['positive_genes']} found; "
            f"minimum required is {MIN_POSITIVES}."
        )
    if label_summary["negative_genes"] < MIN_NEGATIVES:
        safety_issues.append(
            f"Insufficient sampled negatives: {label_summary['negative_genes']} "
            f"found; minimum required is {MIN_NEGATIVES}."
        )
    if safety_issues:
        return _skipped_result(requested_features, label_summary, safety_issues)

    labeled = dataset.dropna(subset=[LABEL_COLUMN]).copy().reset_index(drop=True)
    labeled[LABEL_COLUMN] = pd.to_numeric(
        labeled[LABEL_COLUMN], errors="raise"
    ).astype(int)
    X = labeled.loc[:, requested_features].apply(pd.to_numeric, errors="coerce")
    y = labeled[LABEL_COLUMN]
    gene_names = labeled["gene_name"].astype(str)

    all_missing = [feature for feature in requested_features if X[feature].isna().all()]
    if all_missing:
        raise ValueError(
            "Requested features contain no numeric values and cannot be median "
            f"imputed: {all_missing}"
        )

    models, model_warnings = _build_model_pipelines(y)
    metrics: list[dict[str, Any]] = []
    predictions: list[dict[str, Any]] = []
    feature_importance: list[dict[str, Any]] = []

    for model_name, pipeline in models:
        try:
            result = _cross_validate_model(
                model_name=model_name,
                pipeline=pipeline,
                X=X,
                y=y,
                gene_names=gene_names,
            )
            metrics.append(result["metrics"])
            predictions.extend(result["predictions"])

            fitted_pipeline = clone(pipeline)
            _fit_pipeline(fitted_pipeline, X, y)
            feature_importance.extend(
                _extract_feature_importance(
                    model_name=model_name,
                    pipeline=fitted_pipeline,
                    feature_columns=requested_features,
                )
            )
        except Exception as exc:  # pragma: no cover - defensive model barrier
            warning = f"{model_name} failed during evaluation: {exc}"
            model_warnings.append(warning)
            metrics.append(_failed_metric_row(model_name, y, warning))

    completed = any(row["status"] == "OK" for row in metrics)
    return {
        "status": "COMPLETED" if completed else "SKIPPED",
        "warnings": model_warnings,
        "feature_columns": requested_features,
        "forbidden_features_excluded": FORBIDDEN_FEATURES.copy(),
        "label_summary": label_summary,
        "evaluation_strategy": f"stratified_{N_SPLITS}_fold_cross_validation",
        "cv_summary": {
            "n_splits": N_SPLITS,
            "shuffle": True,
            "random_state": RANDOM_STATE,
        },
        "metrics": metrics,
        "predictions": predictions,
        "feature_importance": feature_importance,
    }


def metrics_to_dataframe(result: dict) -> pd.DataFrame:
    """Convert benchmark metrics to a stable CSV-ready dataframe."""
    rows = result.get("metrics", [])
    if rows:
        return pd.DataFrame(rows).reindex(columns=METRIC_COLUMNS)

    summary = result.get("label_summary", {})
    return pd.DataFrame(
        [
            {
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


def predictions_to_dataframe(result: dict) -> pd.DataFrame:
    """Convert out-of-fold predictions to a stable CSV-ready dataframe."""
    rows = result.get("predictions", [])
    if not rows:
        return pd.DataFrame(columns=PREDICTION_COLUMNS)
    return pd.DataFrame(rows).reindex(columns=PREDICTION_COLUMNS)


def feature_importance_to_dataframe(result: dict) -> pd.DataFrame:
    """Convert full-data model importances to a stable CSV-ready dataframe."""
    rows = result.get("feature_importance", [])
    if not rows:
        return pd.DataFrame(columns=FEATURE_IMPORTANCE_COLUMNS)
    return pd.DataFrame(rows).reindex(columns=FEATURE_IMPORTANCE_COLUMNS)


def _require_columns(
    dataframe: pd.DataFrame,
    required_columns: list[str],
    dataframe_name: str,
) -> None:
    missing = [column for column in required_columns if column not in dataframe.columns]
    if missing:
        raise ValueError(f"{dataframe_name} missing required columns: {missing}")


def _normalize_gene_names(values: pd.Series) -> pd.Series:
    normalized = values.astype("string").str.strip().str.upper()
    return normalized.mask(normalized.eq(""), pd.NA)


def _raise_for_duplicate_genes(dataframe: pd.DataFrame, dataframe_name: str) -> None:
    duplicate_mask = dataframe["gene_name"].duplicated(keep=False)
    if duplicate_mask.any():
        examples = sorted(dataframe.loc[duplicate_mask, "gene_name"].unique())[:5]
        raise ValueError(
            f"{dataframe_name} contains duplicate normalized gene names; "
            f"examples: {examples}"
        )


def _validate_requested_features(
    dataset: pd.DataFrame,
    feature_columns: list[str],
) -> None:
    if not feature_columns:
        raise ValueError("feature_columns must contain at least one allowed feature.")
    if len(feature_columns) != len(set(feature_columns)):
        raise ValueError("feature_columns contains duplicate feature names.")

    forbidden = sorted(set(feature_columns) & set(FORBIDDEN_FEATURES))
    if forbidden:
        raise ValueError(
            "Forbidden leakage-prone features were requested: "
            f"{forbidden}"
        )

    non_allowed = sorted(set(feature_columns) - set(ALLOWED_FEATURES))
    if non_allowed:
        raise ValueError(
            "Only raw/data-derived ALLOWED_FEATURES may be used; disallowed "
            f"features requested: {non_allowed}"
        )

    _require_columns(dataset, ["gene_name", LABEL_COLUMN, *feature_columns], "dataset")
    numeric_labels = pd.to_numeric(dataset[LABEL_COLUMN], errors="coerce")
    invalid_label_mask = numeric_labels.isna() | ~numeric_labels.isin([0, 1])
    if invalid_label_mask.any():
        examples = sorted(
            dataset.loc[invalid_label_mask, LABEL_COLUMN].astype(str).unique()
        )[:5]
        raise ValueError(
            f"external_label must contain only binary 0/1 values; examples: {examples}"
        )


def _label_summary(dataset: pd.DataFrame) -> dict[str, int]:
    if LABEL_COLUMN not in dataset.columns:
        return {"n_genes": 0, "positive_genes": 0, "negative_genes": 0}

    labels = pd.to_numeric(dataset[LABEL_COLUMN], errors="coerce")
    return {
        "n_genes": int(labels.notna().sum()),
        "positive_genes": int((labels == 1).sum()),
        "negative_genes": int((labels == 0).sum()),
    }


def _build_model_pipelines(
    y: pd.Series,
) -> tuple[list[tuple[str, Pipeline]], list[str]]:
    model_warnings: list[str] = []
    models: list[tuple[str, Pipeline]] = [
        (
            "LogisticRegressionElasticNet",
            Pipeline(
                steps=[
                    (
                        "preprocessor",
                        Pipeline(
                            steps=[
                                ("imputer", SimpleImputer(strategy="median")),
                                ("scaler", StandardScaler()),
                            ]
                        ),
                    ),
                    (
                        "model",
                        LogisticRegression(
                            penalty="elasticnet",
                            solver="saga",
                            l1_ratio=0.5,
                            class_weight="balanced",
                            max_iter=5000,
                            random_state=RANDOM_STATE,
                        ),
                    ),
                ]
            ),
        ),
        (
            "RandomForestClassifier",
            Pipeline(
                steps=[
                    (
                        "preprocessor",
                        Pipeline(
                            steps=[("imputer", SimpleImputer(strategy="median"))]
                        ),
                    ),
                    (
                        "model",
                        RandomForestClassifier(
                            n_estimators=500,
                            class_weight="balanced",
                            random_state=RANDOM_STATE,
                            n_jobs=-1,
                        ),
                    ),
                ]
            ),
        ),
    ]

    try:
        from xgboost import XGBClassifier

        models.append(
            (
                "XGBoost",
                Pipeline(
                    steps=[
                        (
                            "preprocessor",
                            Pipeline(
                                steps=[("imputer", SimpleImputer(strategy="median"))]
                            ),
                        ),
                        (
                            "model",
                            XGBClassifier(
                                eval_metric="logloss",
                                random_state=RANDOM_STATE,
                                n_jobs=-1,
                            ),
                        ),
                    ]
                ),
            )
        )
    except ImportError:
        model_warnings.append("xgboost is not installed; skipping XGBoost.")

    return models, model_warnings


def _cross_validate_model(
    model_name: str,
    pipeline: Pipeline,
    X: pd.DataFrame,
    y: pd.Series,
    gene_names: pd.Series,
) -> dict[str, Any]:
    splitter = StratifiedKFold(
        n_splits=N_SPLITS,
        shuffle=True,
        random_state=RANDOM_STATE,
    )
    predicted_labels = np.full(len(y), np.nan)
    predicted_probabilities = np.full(len(y), np.nan)

    for train_index, test_index in splitter.split(X, y):
        fold_pipeline = clone(pipeline)
        _fit_pipeline(
            fold_pipeline,
            X.iloc[train_index],
            y.iloc[train_index],
        )
        predicted_labels[test_index] = fold_pipeline.predict(X.iloc[test_index])
        predicted_probabilities[test_index] = _positive_class_probability(
            fold_pipeline,
            X.iloc[test_index],
        )

    integer_predictions = predicted_labels.astype(int)
    return {
        "metrics": _calculate_metrics(
            model_name=model_name,
            y_true=y.to_numpy(),
            y_pred=integer_predictions,
            y_probability=predicted_probabilities,
        ),
        "predictions": [
            {
                "gene_name": str(gene_names.iloc[index]),
                "external_label": int(y.iloc[index]),
                "predicted_label": int(integer_predictions[index]),
                "predicted_probability": float(predicted_probabilities[index]),
                "model_name": model_name,
            }
            for index in range(len(y))
        ],
    }


def _fit_pipeline(
    pipeline: Pipeline,
    X: pd.DataFrame,
    y: pd.Series,
) -> None:
    with warnings.catch_warnings():
        warnings.filterwarnings(
            "ignore",
            message="'penalty' was deprecated",
            category=FutureWarning,
        )
        pipeline.fit(X, y)


def _positive_class_probability(
    pipeline: Pipeline,
    X: pd.DataFrame,
) -> np.ndarray:
    if hasattr(pipeline, "predict_proba"):
        probabilities = pipeline.predict_proba(X)
        if probabilities.shape[1] >= 2:
            return probabilities[:, 1]
    if hasattr(pipeline, "decision_function"):
        scores = pipeline.decision_function(X)
        return 1 / (1 + np.exp(-scores))
    return np.full(len(X), np.nan)


def _calculate_metrics(
    model_name: str,
    y_true: np.ndarray,
    y_pred: np.ndarray,
    y_probability: np.ndarray,
) -> dict[str, Any]:
    tn, fp, fn, tp = confusion_matrix(y_true, y_pred, labels=[0, 1]).ravel()
    return {
        "model_name": model_name,
        "status": "OK",
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "balanced_accuracy": float(balanced_accuracy_score(y_true, y_pred)),
        "precision": float(precision_score(y_true, y_pred, zero_division=0)),
        "recall": float(recall_score(y_true, y_pred, zero_division=0)),
        "f1_score": float(f1_score(y_true, y_pred, zero_division=0)),
        "mcc": float(matthews_corrcoef(y_true, y_pred)),
        "roc_auc": float(roc_auc_score(y_true, y_probability)),
        "pr_auc": float(average_precision_score(y_true, y_probability)),
        "tn": int(tn),
        "fp": int(fp),
        "fn": int(fn),
        "tp": int(tp),
        "evaluation_strategy": f"stratified_{N_SPLITS}_fold_cross_validation",
        "n_genes": int(len(y_true)),
        "positive_genes": int((y_true == 1).sum()),
        "negative_genes": int((y_true == 0).sum()),
        "warning": "",
    }


def _extract_feature_importance(
    model_name: str,
    pipeline: Pipeline,
    feature_columns: list[str],
) -> list[dict[str, Any]]:
    model = pipeline.named_steps["model"]
    if hasattr(model, "coef_"):
        importance_values = model.coef_[0]
    elif hasattr(model, "feature_importances_"):
        importance_values = model.feature_importances_
    else:
        return []

    rows = [
        {
            "model_name": model_name,
            "feature_name": feature_name,
            "importance": float(importance),
        }
        for feature_name, importance in zip(feature_columns, importance_values)
    ]
    return sorted(rows, key=lambda row: abs(row["importance"]), reverse=True)


def _failed_metric_row(
    model_name: str,
    y: pd.Series,
    warning: str,
) -> dict[str, Any]:
    return {
        "model_name": model_name,
        "status": "FAILED",
        "accuracy": np.nan,
        "balanced_accuracy": np.nan,
        "precision": np.nan,
        "recall": np.nan,
        "f1_score": np.nan,
        "mcc": np.nan,
        "roc_auc": np.nan,
        "pr_auc": np.nan,
        "tn": np.nan,
        "fp": np.nan,
        "fn": np.nan,
        "tp": np.nan,
        "evaluation_strategy": f"stratified_{N_SPLITS}_fold_cross_validation",
        "n_genes": int(len(y)),
        "positive_genes": int((y == 1).sum()),
        "negative_genes": int((y == 0).sum()),
        "warning": warning,
    }


def _skipped_result(
    feature_columns: list[str],
    label_summary: dict[str, int],
    safety_issues: list[str],
) -> dict:
    return {
        "status": "SKIPPED",
        "warnings": safety_issues,
        "feature_columns": feature_columns,
        "forbidden_features_excluded": FORBIDDEN_FEATURES.copy(),
        "label_summary": label_summary,
        "evaluation_strategy": f"stratified_{N_SPLITS}_fold_cross_validation",
        "cv_summary": {
            "n_splits": N_SPLITS,
            "shuffle": True,
            "random_state": RANDOM_STATE,
        },
        "metrics": [],
        "predictions": [],
        "feature_importance": [],
    }
