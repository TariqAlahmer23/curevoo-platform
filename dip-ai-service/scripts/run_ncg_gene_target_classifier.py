from pathlib import Path
import sys

import pandas as pd


ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import OUTPUT_DIR, PROCESSED_DIR
from app.data.loaders import load_csv
from app.models.gene_target_classifier import (
    BASE_FEATURES,
    KNOWLEDGE_AUGMENTED_FEATURES,
    NCG_REPORT_DISCLAIMER,
    build_gene_target_classifier_dataset,
    feature_importance_to_dataframe,
    metrics_to_dataframe,
    predictions_to_dataframe,
    train_evaluate_gene_target_classifier,
)


RANKED_GENES_FILE = PROCESSED_DIR / "target_ranking_v6_evidence_tiers.csv"
NCG_LABELS_FILE = ROOT_DIR / "data" / "external" / "labels" / "external_targets_ncg.csv"
CLASSIFIER_DATASET_FILE = PROCESSED_DIR / "gene_target_classifier_ncg_dataset.csv"

REPORTS_DIR = OUTPUT_DIR / "reports"
METRICS_FILE = REPORTS_DIR / "dip_ai_ncg_gene_classifier_metrics.csv"
REPORT_FILE = REPORTS_DIR / "dip_ai_ncg_gene_classifier_report.txt"
PREDICTIONS_FILE = REPORTS_DIR / "dip_ai_ncg_gene_classifier_predictions.csv"
FEATURE_IMPORTANCE_FILE = REPORTS_DIR / "dip_ai_ncg_gene_classifier_feature_importance.csv"


def main() -> None:
    """Run the full NCG external-label gene target classifier benchmark."""
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

    ranked_genes = load_csv(RANKED_GENES_FILE)
    ncg_labels = load_csv(NCG_LABELS_FILE)
    dataset = build_gene_target_classifier_dataset(
        ranked_genes=ranked_genes,
        external_labels=ncg_labels,
    )
    dataset.to_csv(CLASSIFIER_DATASET_FILE, index=False)

    benchmark_specs = [
        ("base_features", BASE_FEATURES),
        ("knowledge_augmented", KNOWLEDGE_AUGMENTED_FEATURES),
    ]
    results = [
        train_evaluate_gene_target_classifier(
            dataset=dataset,
            feature_set_name=feature_set_name,
            feature_columns=feature_columns,
        )
        for feature_set_name, feature_columns in benchmark_specs
    ]

    metrics = pd.concat(
        [metrics_to_dataframe(result) for result in results],
        ignore_index=True,
    )
    predictions = pd.concat(
        [predictions_to_dataframe(result) for result in results],
        ignore_index=True,
    )
    feature_importance = pd.concat(
        [feature_importance_to_dataframe(result) for result in results],
        ignore_index=True,
    )

    metrics.to_csv(METRICS_FILE, index=False)
    predictions.to_csv(PREDICTIONS_FILE, index=False)
    feature_importance.to_csv(FEATURE_IMPORTANCE_FILE, index=False)
    REPORT_FILE.write_text(
        _build_report(
            dataset=dataset,
            ncg_labels=ncg_labels,
            results=results,
            metrics=metrics,
            feature_importance=feature_importance,
        ),
        encoding="utf-8",
    )

    print(f"NCG gene target classifier dataset rows: {len(dataset)}")
    print(f"NCG positives in dataset: {int((dataset['external_label'] == 1).sum()) if 'external_label' in dataset else 0}")
    print(f"Clean negatives in dataset: {int((dataset['external_label'] == 0).sum()) if 'external_label' in dataset else 0}")
    if not metrics.empty:
        display_columns = [
            "feature_set",
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

    for result in results:
        for warning in result.get("warnings", []):
            print(f"WARNING [{result.get('feature_set')}]: {warning}")

    print(f"Saved classifier dataset: {CLASSIFIER_DATASET_FILE}")
    print(f"Saved metrics: {METRICS_FILE}")
    print(f"Saved report: {REPORT_FILE}")
    print(f"Saved predictions: {PREDICTIONS_FILE}")
    print(f"Saved feature importance: {FEATURE_IMPORTANCE_FILE}")


def _build_report(
    dataset: pd.DataFrame,
    ncg_labels: pd.DataFrame,
    results: list[dict],
    metrics: pd.DataFrame,
    feature_importance: pd.DataFrame,
) -> str:
    positive_count = int((dataset["external_label"] == 1).sum()) if not dataset.empty else 0
    negative_count = int((dataset["external_label"] == 0).sum()) if not dataset.empty else 0
    total_ncg_positive_genes = (
        int(ncg_labels["gene_name"].astype(str).str.upper().nunique())
        if "gene_name" in ncg_labels.columns
        else 0
    )

    lines = [
        "DIP-AI NCG Gene Target Classifier Report",
        "========================================",
        NCG_REPORT_DISCLAIMER,
        "",
        f"NCG positive genes loaded: {total_ncg_positive_genes}",
        f"NCG positives in classifier dataset: {positive_count}",
        f"Clean negatives selected: {negative_count}",
        f"Negative sampling rule: up to 2x positives, random_state=42",
        "",
        "Feature Sets",
        "------------",
        f"base_features: {', '.join(BASE_FEATURES)}",
        f"knowledge_augmented: {', '.join(KNOWLEDGE_AUGMENTED_FEATURES)}",
        (
            "Warning: the knowledge_augmented benchmark includes curated knowledge "
            "features and should not be interpreted as a leakage-minimized benchmark."
        ),
        "",
    ]

    all_warnings = [
        f"{result.get('feature_set')}: {warning}"
        for result in results
        for warning in result.get("warnings", [])
    ]
    if all_warnings:
        lines.extend(["Warnings", "--------"])
        lines.extend(f"- {warning}" for warning in all_warnings)
        lines.append("")

    lines.extend(["Metrics", "-------"])
    if metrics.empty:
        lines.append("No metrics were computed.")
    else:
        for _, row in metrics.iterrows():
            if row.get("status") != "OK":
                lines.append(
                    f"{row.get('feature_set')} / {row.get('model_name')}: "
                    f"{row.get('status')} - {row.get('warning')}"
                )
                continue
            lines.append(
                f"{row['feature_set']} / {row['model_name']}: "
                f"Accuracy={row['accuracy']:.3f}, "
                f"Balanced Accuracy={row['balanced_accuracy']:.3f}, "
                f"Precision={row['precision']:.3f}, "
                f"Recall={row['recall']:.3f}, "
                f"F1={row['f1_score']:.3f}, "
                f"MCC={row['mcc']:.3f}, "
                f"ROC-AUC={row['roc_auc']:.3f}, "
                f"PR-AUC={row['pr_auc']:.3f}"
            )

    lines.extend(["", "Confusion Matrices", "------------------"])
    if metrics.empty:
        lines.append("No confusion matrices were computed.")
    else:
        for _, row in metrics.iterrows():
            if row.get("status") == "OK":
                lines.append(
                    f"{row['feature_set']} / {row['model_name']}: "
                    f"[[{int(row['tn'])}, {int(row['fp'])}], "
                    f"[{int(row['fn'])}, {int(row['tp'])}]]"
                )

    lines.extend(["", "Top Feature Importances", "-----------------------"])
    if feature_importance.empty:
        lines.append("No feature importances were computed.")
    else:
        top_features = (
            feature_importance.sort_values(
                ["feature_set", "model_name", "rank"],
                ascending=[True, True, True],
            )
            .groupby(["feature_set", "model_name"], as_index=False)
            .head(10)
        )
        for (feature_set, model_name), group in top_features.groupby(
            ["feature_set", "model_name"]
        ):
            lines.append(f"{feature_set} / {model_name}:")
            for _, row in group.iterrows():
                lines.append(
                    f"- {row['feature']} importance={row['importance']:.6g}"
                )

    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    main()
