"""Supervised ML benchmark utilities for DIP-AI recurrence-risk evaluation."""

from __future__ import annotations

import json
from typing import Any

import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
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
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler


RANDOM_STATE = 42
TEST_SIZE = 0.25
MIN_LABELED_PATIENTS = 40
MIN_CLASS_COUNT = 5

ID_COLUMNS = {"case_id", "patient_barcode"}
LABEL_COLUMN = "recurrence_label"

METRIC_COLUMNS = [
    "model",
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
    "n_train",
    "n_test",
    "warning",
]

FEATURE_IMPORTANCE_COLUMNS = [
    "model",
    "feature",
    "importance",
    "abs_importance",
    "rank",
]


def train_evaluate_models(dataset: pd.DataFrame) -> dict:
    """
    Train and evaluate supervised recurrence-risk models on patient-level data.

    Returns a structured dictionary with status, warnings, per-model metrics,
    and feature-importance rows. If labels are absent or too sparse, returns a
    skipped result rather than producing scientifically unreliable metrics.
    """
    warnings: list[str] = []
    if LABEL_COLUMN not in dataset.columns:
        return _skipped_result(dataset, ["Dataset is missing recurrence_label."])

    labeled = dataset.dropna(subset=[LABEL_COLUMN]).copy()
    if labeled.empty:
        return _skipped_result(
            labeled,
            [
                "No labeled recurrence patients are available. "
                "Supervised ML evaluation is not reliable."
            ],
        )

    y = labeled[LABEL_COLUMN].astype(int)
    class_counts = y.value_counts().sort_index()
    if len(labeled) < MIN_LABELED_PATIENTS:
        return _skipped_result(
            labeled,
            [
                f"Only {len(labeled)} labeled recurrence patients are available; "
                f"minimum required is {MIN_LABELED_PATIENTS}. "
                "Supervised ML evaluation is not reliable."
            ],
        )
    if class_counts.shape[0] < 2:
        return _skipped_result(
            labeled,
            [
                "Only one recurrence class is present. "
                "Supervised ML evaluation is not reliable."
            ],
        )
    if int(class_counts.min()) < MIN_CLASS_COUNT:
        return _skipped_result(
            labeled,
            [
                f"Smallest recurrence class has {int(class_counts.min())} patients; "
                f"minimum required is {MIN_CLASS_COUNT}. "
                "Supervised ML evaluation is not reliable."
            ],
        )

    X = labeled.drop(columns=[LABEL_COLUMN])
    X = X.drop(columns=[column for column in ID_COLUMNS if column in X.columns])
    X = X.dropna(axis=1, how="all")
    if X.empty:
        return _skipped_result(
            labeled,
            ["No usable supervised ML feature columns are available after cleaning."],
        )

    numeric_features = X.select_dtypes(include=["number", "bool"]).columns.tolist()
    categorical_features = [
        column for column in X.columns if column not in numeric_features
    ]

    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=TEST_SIZE,
        random_state=RANDOM_STATE,
        stratify=y,
    )

    models = _build_model_pipelines(
        numeric_features=numeric_features,
        categorical_features=categorical_features,
        y_train=y_train,
        warnings=warnings,
    )

    metrics: list[dict[str, Any]] = []
    feature_importance: list[dict[str, Any]] = []

    for model_name, pipeline in models:
        try:
            pipeline.fit(X_train, y_train)
            y_pred = pipeline.predict(X_test)
            y_score = _predict_positive_class_score(pipeline, X_test)
            metrics.append(
                _calculate_metrics(
                    model_name=model_name,
                    y_test=y_test,
                    y_pred=y_pred,
                    y_score=y_score,
                    n_train=len(X_train),
                    n_test=len(X_test),
                )
            )
            feature_importance.extend(
                _extract_feature_importance(model_name, pipeline)
            )
        except Exception as exc:  # pragma: no cover - defensive model barrier
            warning = f"{model_name} failed during training/evaluation: {exc}"
            warnings.append(warning)
            metrics.append(_failed_metric_row(model_name, warning, len(X_train), len(X_test)))

    return {
        "status": "COMPLETED" if metrics else "SKIPPED",
        "warnings": warnings,
        "metrics": metrics,
        "feature_importance": feature_importance,
        "label_summary": _label_summary(labeled),
        "split_summary": {
            "test_size": TEST_SIZE,
            "random_state": RANDOM_STATE,
            "n_train": int(len(X_train)),
            "n_test": int(len(X_test)),
        },
        "feature_summary": {
            "n_features": int(X.shape[1]),
            "numeric_features": numeric_features,
            "categorical_features": categorical_features,
        },
    }


def format_ml_benchmark_report(result: dict) -> str:
    """Render a readable supervised ML benchmark report."""
    lines = [
        "DIP-AI Supervised ML Benchmark Report",
        "=====================================",
        "Research-use benchmark only. These metrics do not establish clinical validity.",
        "",
        f"Status: {result.get('status')}",
    ]

    label_summary = result.get("label_summary", {})
    lines.extend(
        [
            f"Labeled patients: {label_summary.get('n_labeled_patients', 0)}",
            f"Class counts: {json.dumps(label_summary.get('class_counts', {}))}",
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
        for row in metrics:
            if row.get("status") != "OK":
                lines.append(f"{row.get('model')}: {row.get('status')} - {row.get('warning')}")
                continue
            lines.append(
                f"{row['model']}: "
                f"F1={row['f1_score']:.3f}, "
                f"MCC={row['mcc']:.3f}, "
                f"ROC-AUC={row['roc_auc']:.3f}, "
                f"PR-AUC={row['pr_auc']:.3f}, "
                f"Precision={row['precision']:.3f}, "
                f"Recall={row['recall']:.3f}, "
                f"Balanced Accuracy={row['balanced_accuracy']:.3f}, "
                f"Confusion Matrix=[[{row['tn']}, {row['fp']}], [{row['fn']}, {row['tp']}]]"
            )
    else:
        lines.extend(
            [
                "Metrics",
                "-------",
                "No model metrics were computed because supervised evaluation was skipped.",
            ]
        )

    return "\n".join(lines) + "\n"


def metrics_to_dataframe(result: dict) -> pd.DataFrame:
    """Convert model metrics to a stable CSV-ready dataframe."""
    metrics = result.get("metrics", [])
    if metrics:
        return pd.DataFrame(metrics).reindex(columns=METRIC_COLUMNS)

    return pd.DataFrame(
        [
            {
                "model": "ALL",
                "status": result.get("status", "SKIPPED"),
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


def _build_model_pipelines(
    numeric_features: list[str],
    categorical_features: list[str],
    y_train: pd.Series,
    warnings: list[str],
) -> list[tuple[str, Pipeline]]:
    models: list[tuple[str, Pipeline]] = [
        (
            "LogisticRegression",
            Pipeline(
                steps=[
                    (
                        "preprocessor",
                        _build_preprocessor(
                            numeric_features,
                            categorical_features,
                            scale_numeric=True,
                        ),
                    ),
                    (
                        "model",
                        LogisticRegression(
                            class_weight="balanced",
                            max_iter=5000,
                            random_state=RANDOM_STATE,
                            solver="liblinear",
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
                        _build_preprocessor(
                            numeric_features,
                            categorical_features,
                            scale_numeric=False,
                        ),
                    ),
                    (
                        "model",
                        RandomForestClassifier(
                            n_estimators=500,
                            random_state=RANDOM_STATE,
                            class_weight="balanced",
                            min_samples_leaf=2,
                            n_jobs=-1,
                        ),
                    ),
                ]
            ),
        ),
    ]

    try:
        from xgboost import XGBClassifier

        class_counts = y_train.value_counts()
        negative_count = int(class_counts.get(0, 0))
        positive_count = int(class_counts.get(1, 0))
        scale_pos_weight = (
            negative_count / positive_count if positive_count > 0 else 1.0
        )
        models.append(
            (
                "XGBoost",
                Pipeline(
                    steps=[
                        (
                            "preprocessor",
                            _build_preprocessor(
                                numeric_features,
                                categorical_features,
                                scale_numeric=False,
                            ),
                        ),
                        (
                            "model",
                            XGBClassifier(
                                n_estimators=300,
                                max_depth=3,
                                learning_rate=0.05,
                                subsample=0.9,
                                colsample_bytree=0.9,
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

    return models


def _build_preprocessor(
    numeric_features: list[str],
    categorical_features: list[str],
    scale_numeric: bool,
) -> ColumnTransformer:
    numeric_steps: list[tuple[str, Any]] = [
        ("imputer", SimpleImputer(strategy="median"))
    ]
    if scale_numeric:
        numeric_steps.append(("scaler", StandardScaler()))

    transformers: list[tuple[str, Pipeline, list[str]]] = []
    if numeric_features:
        transformers.append(("numeric", Pipeline(numeric_steps), numeric_features))
    if categorical_features:
        transformers.append(
            (
                "categorical",
                Pipeline(
                    steps=[
                        ("imputer", SimpleImputer(strategy="most_frequent")),
                        ("encoder", _make_one_hot_encoder()),
                    ]
                ),
                categorical_features,
            )
        )

    return ColumnTransformer(transformers=transformers, remainder="drop")


def _make_one_hot_encoder() -> OneHotEncoder:
    try:
        return OneHotEncoder(handle_unknown="ignore", sparse_output=False)
    except TypeError:  # pragma: no cover - older sklearn compatibility
        return OneHotEncoder(handle_unknown="ignore", sparse=False)


def _predict_positive_class_score(pipeline: Pipeline, X_test: pd.DataFrame) -> np.ndarray:
    model = pipeline.named_steps["model"]
    if hasattr(model, "predict_proba"):
        probabilities = pipeline.predict_proba(X_test)
        if probabilities.shape[1] >= 2:
            return probabilities[:, 1]
    if hasattr(model, "decision_function"):
        return pipeline.decision_function(X_test)

    return np.full(len(X_test), np.nan)


def _calculate_metrics(
    model_name: str,
    y_test: pd.Series,
    y_pred: np.ndarray,
    y_score: np.ndarray,
    n_train: int,
    n_test: int,
) -> dict[str, Any]:
    tn, fp, fn, tp = confusion_matrix(y_test, y_pred, labels=[0, 1]).ravel()
    has_two_test_classes = len(pd.Series(y_test).unique()) == 2
    has_scores = not np.isnan(y_score).all()

    return {
        "model": model_name,
        "status": "OK",
        "accuracy": float(accuracy_score(y_test, y_pred)),
        "balanced_accuracy": float(balanced_accuracy_score(y_test, y_pred)),
        "precision": float(precision_score(y_test, y_pred, zero_division=0)),
        "recall": float(recall_score(y_test, y_pred, zero_division=0)),
        "f1_score": float(f1_score(y_test, y_pred, zero_division=0)),
        "mcc": float(matthews_corrcoef(y_test, y_pred)),
        "roc_auc": (
            float(roc_auc_score(y_test, y_score))
            if has_two_test_classes and has_scores
            else np.nan
        ),
        "pr_auc": (
            float(average_precision_score(y_test, y_score))
            if has_two_test_classes and has_scores
            else np.nan
        ),
        "tn": int(tn),
        "fp": int(fp),
        "fn": int(fn),
        "tp": int(tp),
        "n_train": int(n_train),
        "n_test": int(n_test),
        "warning": "",
    }


def _extract_feature_importance(model_name: str, pipeline: Pipeline) -> list[dict[str, Any]]:
    feature_names = _get_feature_names(pipeline)
    model = pipeline.named_steps["model"]

    if hasattr(model, "coef_"):
        importances = model.coef_[0]
    elif hasattr(model, "feature_importances_"):
        importances = model.feature_importances_
    else:
        return []

    rows = []
    for feature, importance in zip(feature_names, importances):
        rows.append(
            {
                "model": model_name,
                "feature": str(feature),
                "importance": float(importance),
                "abs_importance": float(abs(importance)),
            }
        )

    rows = sorted(rows, key=lambda row: row["abs_importance"], reverse=True)
    for rank, row in enumerate(rows, start=1):
        row["rank"] = rank

    return rows


def _get_feature_names(pipeline: Pipeline) -> list[str]:
    preprocessor = pipeline.named_steps["preprocessor"]
    try:
        return [
            _clean_feature_name(feature)
            for feature in preprocessor.get_feature_names_out()
        ]
    except Exception:  # pragma: no cover - compatibility fallback
        feature_names: list[str] = []
        for transformer_name, _, columns in preprocessor.transformers_:
            if transformer_name == "remainder":
                continue
            feature_names.extend(str(column) for column in columns)
        return feature_names


def _clean_feature_name(feature_name: object) -> str:
    text = str(feature_name)
    for prefix in ["numeric__", "categorical__"]:
        if text.startswith(prefix):
            return text[len(prefix) :]

    return text


def _failed_metric_row(
    model_name: str, warning: str, n_train: int, n_test: int
) -> dict[str, Any]:
    return {
        "model": model_name,
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
        "n_train": int(n_train),
        "n_test": int(n_test),
        "warning": warning,
    }


def _skipped_result(dataset: pd.DataFrame, warnings: list[str]) -> dict:
    return {
        "status": "SKIPPED",
        "warnings": warnings,
        "metrics": [],
        "feature_importance": [],
        "label_summary": _label_summary(dataset),
        "split_summary": {},
        "feature_summary": {},
    }


def _label_summary(dataset: pd.DataFrame) -> dict[str, Any]:
    if LABEL_COLUMN not in dataset.columns:
        return {"n_labeled_patients": 0, "class_counts": {}}

    labeled = dataset.dropna(subset=[LABEL_COLUMN])
    class_counts = labeled[LABEL_COLUMN].astype(int).value_counts().sort_index()
    return {
        "n_labeled_patients": int(len(labeled)),
        "class_counts": {
            str(class_label): int(count)
            for class_label, count in class_counts.items()
        },
    }
