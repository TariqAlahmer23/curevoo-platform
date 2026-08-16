"""Gene-level supervised classifier for external cancer-driver labels."""

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
from sklearn.model_selection import StratifiedKFold, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler


BASE_FEATURES = [
    "mutation_frequency_score",
    "expression_score",
    "protein_impact_score",
    "ranking_score_v3",
    "ranking_score_v4",
    "normal_lung_tpm",
    "safety_score",
    "safety_penalty",
]

KNOWLEDGE_AUGMENTED_FEATURES = [
    *BASE_FEATURES,
    "luad_relevance_score",
    "targetability_score",
    "dormancy_evidence_score",
    "passenger_penalty",
]

FEATURE_COLUMNS = KNOWLEDGE_AUGMENTED_FEATURES
LABEL_COLUMN = "external_label"
RANDOM_STATE = 42
N_SPLITS = 5
MIN_POSITIVES = 20
MIN_NEGATIVES = 20

TIER_5_LOW_EVIDENCE = "Tier_5_Low_Evidence_Target"
GENERAL_CANDIDATE = "General Candidate"

METRIC_COLUMNS = [
    "feature_set",
    "model",
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
    "n_labeled_genes",
    "positive_genes",
    "negative_genes",
    "warning",
]

FEATURE_IMPORTANCE_COLUMNS = [
    "feature_set",
    "model",
    "model_name",
    "feature",
    "importance",
    "abs_importance",
    "rank",
]

PREDICTION_COLUMNS = [
    "gene_name",
    "external_label",
    "model_name",
    "model",
    "feature_set",
    "predicted_probability",
    "predicted_label",
]

REPORT_DISCLAIMER = (
    "External labels are derived from external biomedical knowledge bases. "
    "These metrics evaluate the model's ability to reproduce external target "
    "knowledge, not clinical treatment response or recurrence prediction."
)

NCG_REPORT_DISCLAIMER = (
    "NCG labels evaluate whether the model can reproduce external cancer-driver "
    "knowledge. These metrics do not validate recurrence prediction, treatment "
    "response, or clinical decision-making."
)


def build_gene_target_classifier_dataset(
    ranked_genes: pd.DataFrame,
    external_labels: pd.DataFrame,
) -> pd.DataFrame:
    """
    Build a balanced NCG-style supervised gene-classifier dataset.

    Positive labels are genes appearing in external positive labels. Negatives
    are sampled only from clean low-evidence background genes.
    """
    required_ranked_columns = [
        "gene_name",
        "evidence_tier_v6",
        "target_category_v6",
        "ranking_score_v4",
        "safety_score",
        *BASE_FEATURES,
    ]
    missing_ranked_columns = [
        column for column in required_ranked_columns if column not in ranked_genes.columns
    ]
    if missing_ranked_columns:
        raise ValueError(
            f"Ranked genes missing required classifier columns: {missing_ranked_columns}"
        )

    ranked = ranked_genes.copy()
    ranked["gene_name"] = ranked["gene_name"].astype("string").str.strip().str.upper()
    ranked = ranked.dropna(subset=["gene_name"])
    ranked = ranked[ranked["gene_name"] != ""]

    positive_genes = _positive_gene_set(external_labels)
    ranked["is_external_positive"] = ranked["gene_name"].isin(positive_genes)

    main_features_available = ranked.loc[:, BASE_FEATURES].apply(
        pd.to_numeric, errors="coerce"
    ).notna().all(axis=1)
    passenger_penalty = (
        pd.to_numeric(ranked["passenger_penalty"], errors="coerce").fillna(0)
        if "passenger_penalty" in ranked.columns
        else pd.Series(0, index=ranked.index)
    )

    clean_negative_mask = (
        ~ranked["is_external_positive"]
        & (ranked["evidence_tier_v6"].astype(str) == TIER_5_LOW_EVIDENCE)
        & (ranked["target_category_v6"].astype(str) == GENERAL_CANDIDATE)
        & (pd.to_numeric(ranked["ranking_score_v4"], errors="coerce") < 0.40)
        & (pd.to_numeric(ranked["safety_score"], errors="coerce") >= 0.75)
        & (passenger_penalty == 0)
        & main_features_available
    )
    positive_mask = ranked["is_external_positive"] & main_features_available

    positives = ranked.loc[positive_mask].copy()
    clean_negatives = ranked.loc[clean_negative_mask].copy()

    n_positive = len(positives)
    max_negative_count = 2 * n_positive
    if max_negative_count > 0 and len(clean_negatives) > max_negative_count:
        selected_negatives = clean_negatives.sample(
            n=max_negative_count,
            random_state=RANDOM_STATE,
        )
    else:
        selected_negatives = clean_negatives

    positives[LABEL_COLUMN] = 1
    positives["label_source"] = "NCG"
    positives["selected_as_negative"] = False
    positives["supervised_label_role"] = "positive_ncg"

    selected_negatives[LABEL_COLUMN] = 0
    selected_negatives["label_source"] = "clean_low_evidence_background"
    selected_negatives["selected_as_negative"] = True
    selected_negatives["supervised_label_role"] = "selected_clean_negative"

    dataset = pd.concat([positives, selected_negatives], ignore_index=True)
    if dataset.empty:
        return dataset

    dataset[LABEL_COLUMN] = dataset[LABEL_COLUMN].astype(int)
    dataset = dataset.sort_values(
        [LABEL_COLUMN, "gene_name"], ascending=[False, True]
    ).reset_index(drop=True)

    return dataset


def train_evaluate_gene_target_classifier(
    dataset: pd.DataFrame,
    feature_set_name: str = "knowledge_augmented",
    feature_columns: list[str] | None = None,
) -> dict:
    """
    Train/evaluate gene target classifiers using explicit feature columns.

    The default arguments preserve compatibility with the earlier external-label
    benchmark API.
    """
    if feature_columns is None:
        feature_columns = [column for column in FEATURE_COLUMNS if column in dataset.columns]

    validation_issues = _validate_labeled_dataset(dataset)
    if validation_issues:
        return _skipped_result(dataset, feature_set_name, feature_columns, validation_issues)

    available_features = [
        column
        for column in feature_columns
        if column in dataset.columns
        and not pd.to_numeric(dataset[column], errors="coerce").isna().all()
    ]
    missing_features = [column for column in feature_columns if column not in dataset.columns]
    if missing_features:
        return _skipped_result(
            dataset,
            feature_set_name,
            feature_columns,
            [f"Missing requested feature columns: {missing_features}"],
        )
    if not available_features:
        return _skipped_result(
            dataset,
            feature_set_name,
            feature_columns,
            ["No usable numeric feature columns are available for training."],
        )

    labeled = dataset.dropna(subset=[LABEL_COLUMN]).copy().reset_index(drop=True)
    labeled[LABEL_COLUMN] = labeled[LABEL_COLUMN].astype(int)
    X = labeled.loc[:, available_features].apply(pd.to_numeric, errors="coerce")
    y = labeled[LABEL_COLUMN].astype(int)
    gene_names = (
        labeled["gene_name"].astype(str)
        if "gene_name" in labeled.columns
        else pd.Series([f"gene_{index}" for index in labeled.index], index=labeled.index)
    )

    models, warnings = _build_model_pipelines(y)
    metrics: list[dict[str, Any]] = []
    feature_importance: list[dict[str, Any]] = []
    predictions: list[dict[str, Any]] = []

    use_cross_validation = int(y.value_counts().min()) >= N_SPLITS
    evaluation_strategy = (
        f"stratified_{N_SPLITS}_fold_cv"
        if use_cross_validation
        else "stratified_train_test_split"
    )

    for model_name, pipeline in models:
        try:
            if use_cross_validation:
                model_result = _cross_validate_model(
                    model_name=model_name,
                    feature_set_name=feature_set_name,
                    pipeline=pipeline,
                    X=X,
                    y=y,
                    gene_names=gene_names,
                    evaluation_strategy=evaluation_strategy,
                )
            else:
                model_result = _train_test_model(
                    model_name=model_name,
                    feature_set_name=feature_set_name,
                    pipeline=pipeline,
                    X=X,
                    y=y,
                    gene_names=gene_names,
                    evaluation_strategy=evaluation_strategy,
                )

            metrics.append(model_result["metrics"])
            predictions.extend(model_result["predictions"])

            fitted_pipeline = clone(pipeline)
            _fit_pipeline(fitted_pipeline, X, y)
            feature_importance.extend(
                _extract_feature_importance(
                    model_name=model_name,
                    feature_set_name=feature_set_name,
                    pipeline=fitted_pipeline,
                    feature_columns=available_features,
                )
            )
        except Exception as exc:  # pragma: no cover - defensive model barrier
            warning = f"{model_name} failed during evaluation: {exc}"
            warnings.append(warning)
            metrics.append(
                _failed_metric_row(
                    model_name=model_name,
                    feature_set_name=feature_set_name,
                    warning=warning,
                    y=y,
                    evaluation_strategy=evaluation_strategy,
                )
            )

    return {
        "status": "COMPLETED" if any(row["status"] == "OK" for row in metrics) else "SKIPPED",
        "feature_set": feature_set_name,
        "warnings": warnings,
        "metrics": metrics,
        "feature_importance": feature_importance,
        "predictions": predictions,
        "label_summary": _label_summary(labeled),
        "feature_columns": available_features,
        "evaluation_strategy": evaluation_strategy,
        "cv_summary": {
            "n_splits": N_SPLITS if use_cross_validation else None,
            "random_state": RANDOM_STATE,
        },
    }


def metrics_to_dataframe(result: dict) -> pd.DataFrame:
    """Convert classifier metrics to a stable CSV-ready dataframe."""
    metrics = result.get("metrics", [])
    if metrics:
        return pd.DataFrame(metrics).reindex(columns=METRIC_COLUMNS)

    label_summary = result.get("label_summary", {})
    return pd.DataFrame(
        [
            {
                "feature_set": result.get("feature_set", ""),
                "model": "ALL",
                "model_name": "ALL",
                "status": result.get("status", "SKIPPED"),
                "n_labeled_genes": label_summary.get("n_labeled_genes", 0),
                "positive_genes": label_summary.get("positive_genes", 0),
                "negative_genes": label_summary.get("negative_genes", 0),
                "warning": " | ".join(result.get("warnings", [])),
            }
        ],
        columns=METRIC_COLUMNS,
    )


def feature_importance_to_dataframe(result: dict) -> pd.DataFrame:
    """Convert feature-importance records to a stable CSV-ready dataframe."""
    rows = result.get("feature_importance", [])
    if not rows:
        return pd.DataFrame(columns=FEATURE_IMPORTANCE_COLUMNS)

    return pd.DataFrame(rows).reindex(columns=FEATURE_IMPORTANCE_COLUMNS)


def predictions_to_dataframe(result: dict) -> pd.DataFrame:
    """Convert model predictions to a stable CSV-ready dataframe."""
    rows = result.get("predictions", [])
    if not rows:
        return pd.DataFrame(columns=PREDICTION_COLUMNS)

    return pd.DataFrame(rows).reindex(columns=PREDICTION_COLUMNS)


def format_gene_target_classifier_report(result: dict) -> str:
    """Render a readable single-result report for the external-label classifier."""
    lines = [
        "DIP-AI Gene Target Classifier Report",
        "====================================",
        REPORT_DISCLAIMER,
        "",
        f"Status: {result.get('status')}",
        f"Feature set: {result.get('feature_set', '')}",
    ]

    label_summary = result.get("label_summary", {})
    lines.extend(
        [
            f"Labeled genes: {label_summary.get('n_labeled_genes', 0)}",
            f"Positive genes: {label_summary.get('positive_genes', 0)}",
            f"Negative genes: {label_summary.get('negative_genes', 0)}",
            f"Feature columns: {', '.join(result.get('feature_columns', []))}",
            "",
        ]
    )

    warnings = result.get("warnings", [])
    if warnings:
        lines.extend(["Warnings", "--------"])
        lines.extend(f"- {warning}" for warning in warnings)
        lines.append("")

    metrics = result.get("metrics", [])
    if metrics:
        lines.extend(["Metrics", "-------"])
        lines.extend(_format_metric_row(row) for row in metrics)
    else:
        lines.extend(
            [
                "Metrics",
                "-------",
                "No model metrics were computed because training was skipped.",
            ]
        )

    return "\n".join(lines) + "\n"


def _positive_gene_set(external_labels: pd.DataFrame) -> set[str]:
    if external_labels.empty:
        return set()
    if "gene_name" not in external_labels.columns:
        raise ValueError("External labels missing required column: gene_name")

    if LABEL_COLUMN in external_labels.columns:
        label_values = pd.to_numeric(external_labels[LABEL_COLUMN], errors="coerce")
    elif "label" in external_labels.columns:
        label_values = pd.to_numeric(external_labels["label"], errors="coerce")
    else:
        raise ValueError("External labels missing required label/external_label column")

    positive_mask = label_values == 1
    return set(
        external_labels.loc[positive_mask, "gene_name"]
        .astype("string")
        .str.strip()
        .str.upper()
        .dropna()
    )


def _validate_labeled_dataset(labeled_df: pd.DataFrame) -> list[str]:
    if LABEL_COLUMN not in labeled_df.columns:
        return ["Dataset is missing external_label. Never fabricating labels."]

    dataset = labeled_df.dropna(subset=[LABEL_COLUMN])
    if dataset.empty:
        return [
            "No externally labeled genes are available. Never fabricating labels."
        ]

    numeric_labels = pd.to_numeric(dataset[LABEL_COLUMN], errors="coerce")
    invalid_label_mask = numeric_labels.isna() | ~numeric_labels.isin([0, 1])
    if invalid_label_mask.any():
        examples = sorted(
            dataset.loc[invalid_label_mask, LABEL_COLUMN].astype(str).unique()
        )[:5]
        return [f"external_label must be binary 0/1; invalid examples: {examples}"]

    y = numeric_labels.astype(int)
    positives = int((y == 1).sum())
    negatives = int((y == 0).sum())
    issues = []
    if positives < MIN_POSITIVES:
        issues.append(
            f"Insufficient positive external labels: {positives} found, "
            f"minimum required is {MIN_POSITIVES}."
        )
    if negatives < MIN_NEGATIVES:
        issues.append(
            f"Insufficient clean negative labels: {negatives} found, "
            f"minimum required is {MIN_NEGATIVES}."
        )
    if y.nunique() < 2:
        issues.append("Only one external_label class is present. Training stopped.")

    return issues


def _build_model_pipelines(y: pd.Series) -> tuple[list[tuple[str, Pipeline]], list[str]]:
    warnings: list[str] = []
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
                            n_estimators=300,
                            random_state=RANDOM_STATE,
                            class_weight="balanced",
                            n_jobs=-1,
                        ),
                    ),
                ]
            ),
        ),
    ]

    try:
        from xgboost import XGBClassifier

        positives = int((y == 1).sum())
        negatives = int((y == 0).sum())
        scale_pos_weight = negatives / positives if positives else 1.0
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
                                scale_pos_weight=scale_pos_weight,
                            ),
                        ),
                    ]
                ),
            )
        )
    except ImportError:
        warnings.append("xgboost is not installed; skipping XGBoost.")

    return models, warnings


def _cross_validate_model(
    model_name: str,
    feature_set_name: str,
    pipeline: Pipeline,
    X: pd.DataFrame,
    y: pd.Series,
    gene_names: pd.Series,
    evaluation_strategy: str,
) -> dict[str, Any]:
    splitter = StratifiedKFold(
        n_splits=N_SPLITS,
        shuffle=True,
        random_state=RANDOM_STATE,
    )
    probabilities = np.full(len(y), np.nan)
    predictions = np.full(len(y), np.nan)

    for train_index, test_index in splitter.split(X, y):
        fold_model = clone(pipeline)
        _fit_pipeline(fold_model, X.iloc[train_index], y.iloc[train_index])
        predictions[test_index] = fold_model.predict(X.iloc[test_index])
        probabilities[test_index] = _predict_positive_probability(
            fold_model, X.iloc[test_index]
        )

    metrics = _calculate_metrics(
        model_name=model_name,
        feature_set_name=feature_set_name,
        y_true=y.to_numpy(),
        y_pred=predictions.astype(int),
        y_probability=probabilities,
        evaluation_strategy=evaluation_strategy,
    )

    return {
        "metrics": metrics,
        "predictions": _prediction_rows(
            model_name=model_name,
            feature_set_name=feature_set_name,
            gene_names=gene_names,
            y_true=y,
            predicted_probability=probabilities,
            predicted_label=predictions.astype(int),
        ),
    }


def _train_test_model(
    model_name: str,
    feature_set_name: str,
    pipeline: Pipeline,
    X: pd.DataFrame,
    y: pd.Series,
    gene_names: pd.Series,
    evaluation_strategy: str,
) -> dict[str, Any]:
    train_index, test_index = train_test_split(
        np.arange(len(y)),
        test_size=0.25,
        random_state=RANDOM_STATE,
        stratify=y,
    )
    model = clone(pipeline)
    _fit_pipeline(model, X.iloc[train_index], y.iloc[train_index])
    predicted_label = model.predict(X.iloc[test_index])
    predicted_probability = _predict_positive_probability(model, X.iloc[test_index])

    y_test = y.iloc[test_index]
    metrics = _calculate_metrics(
        model_name=model_name,
        feature_set_name=feature_set_name,
        y_true=y_test.to_numpy(),
        y_pred=predicted_label.astype(int),
        y_probability=predicted_probability,
        evaluation_strategy=evaluation_strategy,
    )

    return {
        "metrics": metrics,
        "predictions": _prediction_rows(
            model_name=model_name,
            feature_set_name=feature_set_name,
            gene_names=gene_names.iloc[test_index].reset_index(drop=True),
            y_true=y_test.reset_index(drop=True),
            predicted_probability=predicted_probability,
            predicted_label=predicted_label.astype(int),
        ),
    }


def _predict_positive_probability(pipeline: Pipeline, X: pd.DataFrame) -> np.ndarray:
    if hasattr(pipeline, "predict_proba"):
        probabilities = pipeline.predict_proba(X)
        if probabilities.shape[1] >= 2:
            return probabilities[:, 1]

    if hasattr(pipeline, "decision_function"):
        scores = pipeline.decision_function(X)
        return 1 / (1 + np.exp(-scores))

    return np.full(len(X), np.nan)


def _fit_pipeline(pipeline: Pipeline, X: pd.DataFrame, y: pd.Series) -> None:
    with warnings.catch_warnings():
        warnings.filterwarnings(
            "ignore",
            message="'penalty' was deprecated",
            category=FutureWarning,
        )
        pipeline.fit(X, y)


def _calculate_metrics(
    model_name: str,
    feature_set_name: str,
    y_true: np.ndarray,
    y_pred: np.ndarray,
    y_probability: np.ndarray,
    evaluation_strategy: str,
) -> dict[str, Any]:
    tn, fp, fn, tp = confusion_matrix(y_true, y_pred, labels=[0, 1]).ravel()
    positives = int((y_true == 1).sum())
    negatives = int((y_true == 0).sum())
    has_probability = not np.isnan(y_probability).all()
    has_two_classes = len(np.unique(y_true)) == 2

    return {
        "feature_set": feature_set_name,
        "model": model_name,
        "model_name": model_name,
        "status": "OK",
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "balanced_accuracy": float(balanced_accuracy_score(y_true, y_pred)),
        "precision": float(precision_score(y_true, y_pred, zero_division=0)),
        "recall": float(recall_score(y_true, y_pred, zero_division=0)),
        "f1_score": float(f1_score(y_true, y_pred, zero_division=0)),
        "mcc": float(matthews_corrcoef(y_true, y_pred)),
        "roc_auc": (
            float(roc_auc_score(y_true, y_probability))
            if has_two_classes and has_probability
            else np.nan
        ),
        "pr_auc": (
            float(average_precision_score(y_true, y_probability))
            if has_two_classes and has_probability
            else np.nan
        ),
        "tn": int(tn),
        "fp": int(fp),
        "fn": int(fn),
        "tp": int(tp),
        "evaluation_strategy": evaluation_strategy,
        "n_labeled_genes": int(len(y_true)),
        "positive_genes": positives,
        "negative_genes": negatives,
        "warning": "",
    }


def _prediction_rows(
    model_name: str,
    feature_set_name: str,
    gene_names: pd.Series,
    y_true: pd.Series,
    predicted_probability: np.ndarray,
    predicted_label: np.ndarray,
) -> list[dict[str, Any]]:
    rows = []
    for index in range(len(y_true)):
        rows.append(
            {
                "gene_name": str(gene_names.iloc[index]),
                "external_label": int(y_true.iloc[index]),
                "model_name": model_name,
                "model": model_name,
                "feature_set": feature_set_name,
                "predicted_probability": float(predicted_probability[index]),
                "predicted_label": int(predicted_label[index]),
            }
        )

    return rows


def _extract_feature_importance(
    model_name: str,
    feature_set_name: str,
    pipeline: Pipeline,
    feature_columns: list[str],
) -> list[dict[str, Any]]:
    model = pipeline.named_steps["model"]
    if hasattr(model, "coef_"):
        importances = model.coef_[0]
    elif hasattr(model, "feature_importances_"):
        importances = model.feature_importances_
    else:
        return []

    rows = [
        {
            "feature_set": feature_set_name,
            "model": model_name,
            "model_name": model_name,
            "feature": feature,
            "importance": float(importance),
            "abs_importance": float(abs(importance)),
        }
        for feature, importance in zip(feature_columns, importances)
    ]
    rows = sorted(rows, key=lambda row: row["abs_importance"], reverse=True)
    for rank, row in enumerate(rows, start=1):
        row["rank"] = rank

    return rows


def _failed_metric_row(
    model_name: str,
    feature_set_name: str,
    warning: str,
    y: pd.Series,
    evaluation_strategy: str,
) -> dict[str, Any]:
    positives = int((y == 1).sum())
    negatives = int((y == 0).sum())
    return {
        "feature_set": feature_set_name,
        "model": model_name,
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
        "evaluation_strategy": evaluation_strategy,
        "n_labeled_genes": int(len(y)),
        "positive_genes": positives,
        "negative_genes": negatives,
        "warning": warning,
    }


def _skipped_result(
    labeled_df: pd.DataFrame,
    feature_set_name: str,
    feature_columns: list[str],
    warnings: list[str],
) -> dict:
    return {
        "status": "SKIPPED",
        "feature_set": feature_set_name,
        "warnings": warnings,
        "metrics": [],
        "feature_importance": [],
        "predictions": [],
        "label_summary": _label_summary(labeled_df),
        "feature_columns": [
            column for column in feature_columns if column in labeled_df.columns
        ],
        "evaluation_strategy": None,
        "cv_summary": {
            "n_splits": N_SPLITS,
            "random_state": RANDOM_STATE,
        },
    }


def _label_summary(labeled_df: pd.DataFrame) -> dict[str, Any]:
    if LABEL_COLUMN not in labeled_df.columns:
        return {
            "n_labeled_genes": 0,
            "positive_genes": 0,
            "negative_genes": 0,
            "class_counts": {},
        }

    dataset = labeled_df.dropna(subset=[LABEL_COLUMN])
    if dataset.empty:
        return {
            "n_labeled_genes": 0,
            "positive_genes": 0,
            "negative_genes": 0,
            "class_counts": {},
        }

    y = pd.to_numeric(dataset[LABEL_COLUMN], errors="coerce").dropna().astype(int)
    class_counts = y.value_counts().sort_index()
    return {
        "n_labeled_genes": int(len(y)),
        "positive_genes": int((y == 1).sum()),
        "negative_genes": int((y == 0).sum()),
        "class_counts": {
            str(class_label): int(count)
            for class_label, count in class_counts.items()
        },
    }


def _format_metric_row(row: dict[str, Any]) -> str:
    if row.get("status") != "OK":
        return f"{row.get('model_name')}: {row.get('status')} - {row.get('warning')}"

    return (
        f"{row['feature_set']} / {row['model_name']}: "
        f"Accuracy={row['accuracy']:.3f}, "
        f"Balanced Accuracy={row['balanced_accuracy']:.3f}, "
        f"Precision={row['precision']:.3f}, "
        f"Recall={row['recall']:.3f}, "
        f"F1={row['f1_score']:.3f}, "
        f"MCC={row['mcc']:.3f}, "
        f"ROC-AUC={row['roc_auc']:.3f}, "
        f"PR-AUC={row['pr_auc']:.3f}, "
        f"Confusion Matrix=[[{row['tn']}, {row['fp']}], [{row['fn']}, {row['tp']}]]"
    )
