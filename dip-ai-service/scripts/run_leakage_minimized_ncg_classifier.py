"""Run the leakage-minimized NCG gene-classifier benchmark."""

from pathlib import Path
import sys

import pandas as pd


ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import OUTPUT_DIR, PROCESSED_DIR
from app.models.leakage_minimized_classifier import (
    ALLOWED_FEATURES,
    FORBIDDEN_FEATURES,
    build_leakage_minimized_dataset,
    feature_importance_to_dataframe,
    metrics_to_dataframe,
    predictions_to_dataframe,
    train_evaluate_leakage_minimized_classifier,
)


TARGET_FEATURES_FILE = PROCESSED_DIR / "target_features_v2.csv"
GTEX_SAFETY_FEATURES_FILE = PROCESSED_DIR / "gtex_lung_safety_features.csv"
NCG_LABELS_FILE = ROOT_DIR / "data" / "external" / "labels" / "external_targets_ncg.csv"

DATASET_FILE = (
    PROCESSED_DIR / "gene_target_classifier_ncg_leakage_minimized_dataset.csv"
)
REPORTS_DIR = OUTPUT_DIR / "reports"
METRICS_FILE = REPORTS_DIR / "dip_ai_ncg_leakage_minimized_metrics.csv"
REPORT_FILE = REPORTS_DIR / "dip_ai_ncg_leakage_minimized_report.txt"
PREDICTIONS_FILE = (
    REPORTS_DIR / "dip_ai_ncg_leakage_minimized_predictions.csv"
)
FEATURE_IMPORTANCE_FILE = (
    REPORTS_DIR / "dip_ai_ncg_leakage_minimized_feature_importance.csv"
)

DISCLAIMER = (
    "This leakage-minimized benchmark evaluates whether raw mutation, expression, "
    "and GTEx normal lung features can reproduce external NCG cancer-driver labels. "
    "It does not validate recurrence prediction, treatment response, or clinical "
    "decision-making."
)


def main() -> None:
    """Build, evaluate, and save the leakage-minimized NCG benchmark."""
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

    target_features = _load_csv(TARGET_FEATURES_FILE)
    gtex_safety_features = _load_csv(GTEX_SAFETY_FEATURES_FILE)
    ncg_labels = _load_csv(NCG_LABELS_FILE)

    dataset = build_leakage_minimized_dataset(
        target_features=target_features,
        gtex_safety_features=gtex_safety_features,
        ncg_labels=ncg_labels,
        negative_ratio=2,
        random_state=42,
    )
    dataset.to_csv(DATASET_FILE, index=False)

    result = train_evaluate_leakage_minimized_classifier(
        dataset=dataset,
        feature_columns=ALLOWED_FEATURES,
    )
    metrics = metrics_to_dataframe(result)
    predictions = predictions_to_dataframe(result)
    feature_importance = feature_importance_to_dataframe(result)

    metrics.to_csv(METRICS_FILE, index=False)
    predictions.to_csv(PREDICTIONS_FILE, index=False)
    feature_importance.to_csv(FEATURE_IMPORTANCE_FILE, index=False)
    REPORT_FILE.write_text(
        _build_report(
            result=result,
            metrics=metrics,
            feature_importance=feature_importance,
        ),
        encoding="utf-8",
    )

    summary = result.get("label_summary", {})
    print(f"Status: {result.get('status')}")
    print(f"NCG positives: {summary.get('positive_genes', 0)}")
    print(f"Sampled non-NCG negatives: {summary.get('negative_genes', 0)}")
    if not metrics.empty:
        display_columns = [
            "model_name",
            "status",
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
        ]
        print(metrics.loc[:, display_columns].to_string(index=False))

    for warning in result.get("warnings", []):
        print(f"WARNING: {warning}")

    print("Saved files:")
    for path in [
        DATASET_FILE,
        METRICS_FILE,
        REPORT_FILE,
        PREDICTIONS_FILE,
        FEATURE_IMPORTANCE_FILE,
    ]:
        print(path)


def _load_csv(path: Path) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(f"Required input file not found: {path}")
    return pd.read_csv(path, low_memory=False)


def _build_report(
    result: dict,
    metrics: pd.DataFrame,
    feature_importance: pd.DataFrame,
) -> str:
    summary = result.get("label_summary", {})
    lines = [
        "DIP-AI NCG Leakage-Minimized Gene Classifier Report",
        "===================================================",
        DISCLAIMER,
        "",
        f"Status: {result.get('status')}",
        f"NCG positive genes: {summary.get('positive_genes', 0)}",
        f"Sampled non-NCG negative genes: {summary.get('negative_genes', 0)}",
        f"Total benchmark genes: {summary.get('n_genes', 0)}",
        f"Evaluation: {result.get('evaluation_strategy')}",
        "",
        "Allowed Features Used",
        "---------------------",
        *[f"- {feature}" for feature in result.get("feature_columns", [])],
        "",
        "Forbidden Features Explicitly Excluded",
        "--------------------------------------",
        *[
            f"- {feature}"
            for feature in result.get(
                "forbidden_features_excluded",
                FORBIDDEN_FEATURES,
            )
        ],
        "",
    ]

    benchmark_warnings = result.get("warnings", [])
    if benchmark_warnings:
        lines.extend(["Warnings", "--------"])
        lines.extend(f"- {warning}" for warning in benchmark_warnings)
        lines.append("")

    successful_metrics = metrics[metrics["status"] == "OK"].copy()
    lines.extend(["Metrics", "-------"])
    if successful_metrics.empty:
        lines.append("No metrics were computed because benchmark training was skipped.")
    else:
        metric_columns = [
            "model_name",
            "accuracy",
            "balanced_accuracy",
            "precision",
            "recall",
            "f1_score",
            "mcc",
            "roc_auc",
            "pr_auc",
        ]
        lines.append(
            successful_metrics.loc[:, metric_columns]
            .round(4)
            .to_string(index=False)
        )

    lines.extend(["", "Aggregate Out-of-Fold Confusion Matrices", "-----------------------------------------"])
    if successful_metrics.empty:
        lines.append("No confusion matrices were computed.")
    else:
        for _, row in successful_metrics.iterrows():
            lines.append(
                f"{row['model_name']}: "
                f"[[{int(row['tn'])}, {int(row['fp'])}], "
                f"[{int(row['fn'])}, {int(row['tp'])}]]"
            )

    lines.extend(["", "Top Feature Importances", "-----------------------"])
    if feature_importance.empty:
        lines.append("No feature importances were computed.")
    else:
        for model_name in feature_importance["model_name"].drop_duplicates():
            lines.append(f"{model_name}:")
            model_rows = feature_importance[
                feature_importance["model_name"] == model_name
            ].copy()
            model_rows["abs_importance"] = model_rows["importance"].abs()
            model_rows = model_rows.sort_values(
                "abs_importance",
                ascending=False,
            ).head(10)
            for _, row in model_rows.iterrows():
                lines.append(
                    f"- {row['feature_name']}: {row['importance']:.6g}"
                )

    lines.extend(
        [
            "",
            "Interpretation",
            "--------------",
            (
                "If performance remains strong, the ML signal is less likely to be "
                "caused by ranking-score leakage."
            ),
            (
                "If performance drops strongly, the previous benchmark was likely "
                "inflated by derived ranking/safety features."
            ),
            "",
        ]
    )
    return "\n".join(lines)


if __name__ == "__main__":
    main()
