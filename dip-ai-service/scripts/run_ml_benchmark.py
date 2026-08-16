from pathlib import Path
import sys

import pandas as pd


ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import OUTPUT_DIR, PROCESSED_DIR
from app.data.loaders import load_all_data
from app.features.patient_features import build_patient_level_features
from app.models.ml_benchmark import (
    feature_importance_to_dataframe,
    format_ml_benchmark_report,
    metrics_to_dataframe,
    train_evaluate_models,
)


PATIENT_DATASET_FILE = PROCESSED_DIR / "patient_level_ml_dataset.csv"
REPORTS_DIR = OUTPUT_DIR / "reports"
METRICS_FILE = REPORTS_DIR / "dip_ai_ml_benchmark_metrics.csv"
REPORT_FILE = REPORTS_DIR / "dip_ai_ml_benchmark_report.txt"
FEATURE_IMPORTANCE_FILE = REPORTS_DIR / "dip_ai_ml_feature_importance.csv"


def main() -> None:
    """Build patient-level ML dataset and run supervised benchmark."""
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

    rna, mutations, clinical = load_all_data()
    dataset = build_patient_level_features(mutations, rna, clinical)
    dataset.to_csv(PATIENT_DATASET_FILE, index=False)

    result = train_evaluate_models(dataset)
    metrics = metrics_to_dataframe(result)
    feature_importance = feature_importance_to_dataframe(result)

    metrics.to_csv(METRICS_FILE, index=False)
    feature_importance.to_csv(FEATURE_IMPORTANCE_FILE, index=False)
    REPORT_FILE.write_text(format_ml_benchmark_report(result), encoding="utf-8")

    print(f"ML benchmark status: {result['status']}")
    print(
        "Labeled patients: "
        f"{result.get('label_summary', {}).get('n_labeled_patients', 0)}"
    )
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
        print("No model metrics computed.")

    print(f"Saved patient ML dataset: {PATIENT_DATASET_FILE}")
    print(f"Saved metrics: {METRICS_FILE}")
    print(f"Saved report: {REPORT_FILE}")
    print(f"Saved feature importance: {FEATURE_IMPORTANCE_FILE}")


if __name__ == "__main__":
    main()
