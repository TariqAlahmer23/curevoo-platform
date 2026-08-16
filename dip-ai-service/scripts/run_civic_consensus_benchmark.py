"""Run the raw-feature NCG+CIViC consensus gene benchmark."""

from pathlib import Path
import sys

import pandas as pd


ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import OUTPUT_DIR, PROCESSED_DIR
from app.models.consensus_external_labels import (
    build_consensus_external_labels,
)
from app.models.consensus_gene_classifier import (
    CONSENSUS_FEATURES,
    build_consensus_classifier_dataset,
    feature_importance_to_dataframe,
    metrics_to_dataframe,
    predictions_to_dataframe,
    train_evaluate_consensus_classifier,
)


TARGET_FEATURES_FILE = PROCESSED_DIR / "target_features_v2.csv"
GTEX_SAFETY_FEATURES_FILE = PROCESSED_DIR / "gtex_lung_safety_features.csv"
RANKED_TARGETS_FILE = PROCESSED_DIR / "target_ranking_v6_evidence_tiers.csv"
NCG_LABELS_FILE = (
    ROOT_DIR / "data" / "external" / "labels" / "external_targets_ncg.csv"
)
CIVIC_LABELS_FILE = (
    ROOT_DIR / "data" / "external" / "labels" / "external_targets_civic.csv"
)

CONSENSUS_LABELS_FILE = (
    ROOT_DIR
    / "data"
    / "external"
    / "labels"
    / "external_targets_consensus_ncg_civic.csv"
)
ANY_SOURCE_DATASET_FILE = (
    PROCESSED_DIR / "gene_target_classifier_consensus_any_source_dataset.csv"
)
HIGH_CONFIDENCE_DATASET_FILE = (
    PROCESSED_DIR
    / "gene_target_classifier_consensus_high_confidence_dataset.csv"
)

REPORTS_DIR = OUTPUT_DIR / "reports"
METRICS_FILE = REPORTS_DIR / "dip_ai_consensus_ncg_civic_metrics.csv"
REPORT_FILE = REPORTS_DIR / "dip_ai_consensus_ncg_civic_report.txt"
PREDICTIONS_FILE = (
    REPORTS_DIR / "dip_ai_consensus_ncg_civic_predictions.csv"
)
FEATURE_IMPORTANCE_FILE = (
    REPORTS_DIR / "dip_ai_consensus_ncg_civic_feature_importance.csv"
)

DISCLAIMER = (
    "Consensus labels from NCG and CIViC evaluate reproduction of external "
    "cancer-driver/clinical cancer evidence. These metrics do not validate "
    "recurrence prediction, treatment response, or clinical decision-making."
)


def main() -> None:
    """Build labels and datasets, evaluate both modes, and save outputs."""
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    CONSENSUS_LABELS_FILE.parent.mkdir(parents=True, exist_ok=True)

    target_features = _load_csv(TARGET_FEATURES_FILE)
    gtex_safety_features = _load_csv(GTEX_SAFETY_FEATURES_FILE)
    ranked_targets = _load_csv(RANKED_TARGETS_FILE)
    ncg_labels = _load_csv(NCG_LABELS_FILE)
    civic_labels = _load_csv(CIVIC_LABELS_FILE)

    consensus_labels = build_consensus_external_labels(
        ranked_genes=ranked_targets,
        ncg_labels=ncg_labels,
        civic_labels=civic_labels,
    )
    consensus_labels.to_csv(CONSENSUS_LABELS_FILE, index=False)

    datasets = {
        "any_source": build_consensus_classifier_dataset(
            target_features=target_features,
            gtex_safety_features=gtex_safety_features,
            consensus_labels=consensus_labels,
            label_mode="any_source",
            negative_ratio=2,
            random_state=42,
        ),
        "high_confidence": build_consensus_classifier_dataset(
            target_features=target_features,
            gtex_safety_features=gtex_safety_features,
            consensus_labels=consensus_labels,
            label_mode="high_confidence",
            negative_ratio=2,
            random_state=42,
        ),
    }
    datasets["any_source"].to_csv(ANY_SOURCE_DATASET_FILE, index=False)
    datasets["high_confidence"].to_csv(
        HIGH_CONFIDENCE_DATASET_FILE,
        index=False,
    )

    print("Built consensus labels and datasets. Running two 5-fold benchmarks...")
    results = {
        label_mode: train_evaluate_consensus_classifier(
            dataset=dataset,
            feature_columns=CONSENSUS_FEATURES,
            label_mode=label_mode,
        )
        for label_mode, dataset in datasets.items()
    }

    metrics = pd.concat(
        [metrics_to_dataframe(result) for result in results.values()],
        ignore_index=True,
    )
    predictions = pd.concat(
        [predictions_to_dataframe(result) for result in results.values()],
        ignore_index=True,
    )
    feature_importance = pd.concat(
        [
            feature_importance_to_dataframe(result)
            for result in results.values()
        ],
        ignore_index=True,
    )

    metrics.to_csv(METRICS_FILE, index=False)
    predictions.to_csv(PREDICTIONS_FILE, index=False)
    feature_importance.to_csv(FEATURE_IMPORTANCE_FILE, index=False)
    REPORT_FILE.write_text(
        _build_report(
            ncg_labels=ncg_labels,
            civic_labels=civic_labels,
            consensus_labels=consensus_labels,
            datasets=datasets,
            results=results,
            metrics=metrics,
            feature_importance=feature_importance,
        ),
        encoding="utf-8",
    )

    print(metrics.loc[
        :,
        [
            "label_mode",
            "model_name",
            "status",
            "balanced_accuracy",
            "f1_score",
            "mcc",
            "roc_auc",
            "pr_auc",
        ],
    ].round(4).to_string(index=False))
    for label_mode, result in results.items():
        for warning in result.get("warnings", []):
            print(f"WARNING [{label_mode}]: {warning}")

    print("Saved files:")
    for path in [
        CONSENSUS_LABELS_FILE,
        ANY_SOURCE_DATASET_FILE,
        HIGH_CONFIDENCE_DATASET_FILE,
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
    ncg_labels: pd.DataFrame,
    civic_labels: pd.DataFrame,
    consensus_labels: pd.DataFrame,
    datasets: dict[str, pd.DataFrame],
    results: dict[str, dict],
    metrics: pd.DataFrame,
    feature_importance: pd.DataFrame,
) -> str:
    ncg_genes = _positive_gene_set(ncg_labels)
    civic_genes = _positive_gene_set(civic_labels)
    overlap_genes = ncg_genes & civic_genes
    consensus_counts = consensus_labels["consensus_confidence"].value_counts()
    successful = metrics[metrics["status"] == "OK"].copy()

    lines = [
        "DIP-AI NCG + CIViC Consensus Gene Benchmark",
        "==========================================",
        DISCLAIMER,
        "",
        "External Evidence Coverage",
        "--------------------------",
        f"NCG positive count: {len(ncg_genes)}",
        f"CIViC positive count: {len(civic_genes)}",
        f"NCG/CIViC overlap count: {len(overlap_genes)}",
        (
            "Any-source positive count in ranked-gene universe: "
            f"{int((consensus_labels['consensus_label'] == 1).sum())}"
        ),
        (
            "High-confidence positive count in ranked-gene universe: "
            f"{int(consensus_counts.get('high_confidence_positive', 0))}"
        ),
        (
            "CIViC-only added positives in ranked-gene universe: "
            f"{int(((consensus_labels['in_civic']) & (~consensus_labels['in_ncg'])).sum())}"
        ),
        (
            "Negative candidates in ranked-gene universe: "
            f"{int(consensus_counts.get('negative_candidate', 0))}"
        ),
        "",
        "Classifier Datasets",
        "-------------------",
    ]
    for label_mode, dataset in datasets.items():
        lines.extend(
            [
                f"{label_mode}:",
                f"  Positives: {int((dataset['external_label'] == 1).sum())}",
                f"  Sampled negatives: {int((dataset['external_label'] == 0).sum())}",
                f"  Total genes: {len(dataset)}",
            ]
        )

    lines.extend(
        [
            "",
            f"Allowed raw features ({len(CONSENSUS_FEATURES)}):",
            ", ".join(CONSENSUS_FEATURES),
            "",
            "Metrics",
            "-------",
        ]
    )
    if successful.empty:
        lines.append("No successful model metrics were produced.")
    else:
        metric_columns = [
            "label_mode",
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
            successful.loc[:, metric_columns].round(4).to_string(index=False)
        )

    lines.extend(
        [
            "",
            "Aggregate Out-of-Fold Confusion Matrices",
            "-----------------------------------------",
        ]
    )
    if successful.empty:
        lines.append("No confusion matrices were produced.")
    else:
        for _, row in successful.iterrows():
            lines.append(
                f"{row['label_mode']} / {row['model_name']}: "
                f"[[{int(row['tn'])}, {int(row['fp'])}], "
                f"[{int(row['fn'])}, {int(row['tp'])}]]"
            )

    lines.extend(["", "Top Feature Importances", "-----------------------"])
    if feature_importance.empty:
        lines.append("No feature importances were produced.")
    else:
        for label_mode in ["any_source", "high_confidence"]:
            for model_name in feature_importance.loc[
                feature_importance["label_mode"] == label_mode,
                "model_name",
            ].drop_duplicates():
                rows = feature_importance[
                    (feature_importance["label_mode"] == label_mode)
                    & (feature_importance["model_name"] == model_name)
                ].copy()
                rows["abs_importance"] = rows["importance"].abs()
                rows = rows.sort_values(
                    "abs_importance",
                    ascending=False,
                ).head(10)
                lines.append(f"{label_mode} / {model_name}:")
                for _, row in rows.iterrows():
                    lines.append(
                        f"- {row['feature_name']}: {row['importance']:.6g}"
                    )

    lines.extend(["", "Interpretation", "--------------"])
    lines.extend(
        _interpret_results(
            consensus_labels=consensus_labels,
            successful_metrics=successful,
        )
    )

    warnings = [
        warning
        for result in results.values()
        for warning in result.get("warnings", [])
    ]
    if warnings:
        lines.extend(["", "Warnings", "--------"])
        lines.extend(f"- {warning}" for warning in warnings)

    lines.append("")
    return "\n".join(lines)


def _interpret_results(
    consensus_labels: pd.DataFrame,
    successful_metrics: pd.DataFrame,
) -> list[str]:
    civic_only = int(
        (
            consensus_labels["in_civic"]
            & ~consensus_labels["in_ncg"]
        ).sum()
    )
    lines = [
        (
            f"- CIViC increased external evidence coverage by {civic_only} "
            "CIViC-only positive genes within the ranked-gene universe."
        )
    ]

    any_metrics = successful_metrics[
        successful_metrics["label_mode"] == "any_source"
    ].set_index("model_name")
    high_metrics = successful_metrics[
        successful_metrics["label_mode"] == "high_confidence"
    ].set_index("model_name")
    common_models = any_metrics.index.intersection(high_metrics.index)
    if len(common_models):
        roc_delta = float(
            (
                high_metrics.loc[common_models, "roc_auc"]
                - any_metrics.loc[common_models, "roc_auc"]
            ).mean()
        )
        f1_delta = float(
            (
                high_metrics.loc[common_models, "f1_score"]
                - any_metrics.loc[common_models, "f1_score"]
            ).mean()
        )
        direction = "improved" if roc_delta > 0 else "did not improve"
        lines.append(
            f"- High-confidence labels {direction} mean ROC-AUC relative to "
            f"any-source labels (mean delta={roc_delta:+.4f}; "
            f"F1 delta={f1_delta:+.4f} across matching models). Cohort sizes "
            "differ, so this is a benchmark comparison, not a paired clinical test."
        )
    else:
        lines.append(
            "- High-confidence versus any-source performance could not be "
            "compared because no matching successful models were available."
        )

    if successful_metrics.empty:
        lines.append(
            "- Raw-feature reproduction of consensus labels could not be assessed."
        )
    else:
        best = successful_metrics.sort_values(
            ["roc_auc", "f1_score"],
            ascending=False,
        ).iloc[0]
        strength = (
            "strong"
            if best["roc_auc"] >= 0.80
            else "moderate"
            if best["roc_auc"] >= 0.70
            else "limited"
        )
        lines.append(
            f"- The best raw-feature model achieved ROC-AUC={best['roc_auc']:.4f} "
            f"and F1={best['f1_score']:.4f} for {best['label_mode']}; this is "
            f"{strength} reproduction of external labels and does not establish "
            "clinical validity."
        )
    return lines


def _positive_gene_set(labels: pd.DataFrame) -> set[str]:
    if "gene_name" not in labels.columns:
        raise ValueError("External labels missing required column: gene_name")
    work = labels.copy()
    if "label" in work.columns:
        work = work.loc[
            pd.to_numeric(work["label"], errors="coerce").eq(1)
        ]
    return set(
        work["gene_name"]
        .astype("string")
        .str.strip()
        .str.upper()
        .dropna()
    )


if __name__ == "__main__":
    main()
