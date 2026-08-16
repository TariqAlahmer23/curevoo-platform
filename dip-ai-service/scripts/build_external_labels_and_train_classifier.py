from pathlib import Path
import sys


ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import OUTPUT_DIR, PROCESSED_DIR
from app.data.external_label_loaders import load_all_external_label_sources
from app.data.loaders import load_csv
from app.models.external_labels import build_external_gene_labels
from app.models.gene_target_classifier import (
    feature_importance_to_dataframe,
    format_gene_target_classifier_report,
    metrics_to_dataframe,
    predictions_to_dataframe,
    train_evaluate_gene_target_classifier,
)


LABELS_DIR = ROOT_DIR / "data" / "external" / "labels"
RANKED_GENES_FILE = PROCESSED_DIR / "target_ranking_v6_evidence_tiers.csv"
EXTERNAL_GENE_LABELS_FILE = PROCESSED_DIR / "external_gene_labels.csv"
CLASSIFIER_DATASET_FILE = PROCESSED_DIR / "gene_target_classifier_dataset.csv"

REPORTS_DIR = OUTPUT_DIR / "reports"
METRICS_FILE = REPORTS_DIR / "dip_ai_gene_target_classifier_metrics.csv"
REPORT_FILE = REPORTS_DIR / "dip_ai_gene_target_classifier_report.txt"
FEATURE_IMPORTANCE_FILE = (
    REPORTS_DIR / "dip_ai_gene_target_classifier_feature_importance.csv"
)
PREDICTIONS_FILE = REPORTS_DIR / "dip_ai_gene_target_classifier_predictions.csv"


def main() -> None:
    """Build external gene labels and train/evaluate the gene target classifier."""
    LABELS_DIR.mkdir(parents=True, exist_ok=True)
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

    ranked_genes = load_csv(RANKED_GENES_FILE)
    external_evidence = load_all_external_label_sources(LABELS_DIR)
    external_gene_labels = build_external_gene_labels(
        ranked_genes=ranked_genes,
        external_evidence=external_evidence,
    )
    classifier_dataset = external_gene_labels.dropna(
        subset=["external_label"]
    ).copy()
    if not classifier_dataset.empty:
        classifier_dataset["external_label"] = classifier_dataset[
            "external_label"
        ].astype(int)

    external_gene_labels.to_csv(EXTERNAL_GENE_LABELS_FILE, index=False)
    classifier_dataset.to_csv(CLASSIFIER_DATASET_FILE, index=False)

    result = train_evaluate_gene_target_classifier(classifier_dataset)
    metrics = metrics_to_dataframe(result)
    feature_importance = feature_importance_to_dataframe(result)
    predictions = predictions_to_dataframe(result)

    metrics.to_csv(METRICS_FILE, index=False)
    feature_importance.to_csv(FEATURE_IMPORTANCE_FILE, index=False)
    predictions.to_csv(PREDICTIONS_FILE, index=False)
    REPORT_FILE.write_text(
        format_gene_target_classifier_report(result),
        encoding="utf-8",
    )

    label_summary = result.get("label_summary", {})
    print(f"Gene target classifier status: {result['status']}")
    print(f"External evidence rows loaded: {len(external_evidence)}")
    print(f"Labeled genes: {label_summary.get('n_labeled_genes', 0)}")
    print(f"Positive genes: {label_summary.get('positive_genes', 0)}")
    print(f"Negative genes: {label_summary.get('negative_genes', 0)}")
    for warning in result.get("warnings", []):
        print(f"WARNING: {warning}")

    if result.get("metrics"):
        display_columns = [
            "model",
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
        ]
        print(metrics.loc[:, display_columns].to_string(index=False))
    else:
        print("No classifier metrics computed.")

    print(f"Saved external gene labels: {EXTERNAL_GENE_LABELS_FILE}")
    print(f"Saved classifier dataset: {CLASSIFIER_DATASET_FILE}")
    print(f"Saved metrics: {METRICS_FILE}")
    print(f"Saved report: {REPORT_FILE}")
    print(f"Saved feature importance: {FEATURE_IMPORTANCE_FILE}")
    print(f"Saved predictions: {PREDICTIONS_FILE}")


if __name__ == "__main__":
    main()
