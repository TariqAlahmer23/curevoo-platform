"""Run the six-experiment DIP-AI NCG ablation study."""

from pathlib import Path
import sys

import pandas as pd


ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import OUTPUT_DIR, PROCESSED_DIR
from app.models.ablation_study import (
    EXPERIMENT_CONFIGS,
    build_ablation_datasets,
    feature_importance_to_dataframe,
    metrics_to_dataframe,
    run_ablation_study,
)


TARGET_FEATURES_FILE = PROCESSED_DIR / "target_features_v2.csv"
GTEX_SAFETY_FEATURES_FILE = PROCESSED_DIR / "gtex_lung_safety_features.csv"
RANKED_TARGETS_FILE = PROCESSED_DIR / "target_ranking_v6_evidence_tiers.csv"
NCG_LABELS_FILE = (
    ROOT_DIR / "data" / "external" / "labels" / "external_targets_ncg.csv"
)

REPORTS_DIR = OUTPUT_DIR / "reports"
METRICS_FILE = REPORTS_DIR / "dip_ai_ncg_ablation_metrics.csv"
REPORT_FILE = REPORTS_DIR / "dip_ai_ncg_ablation_report.txt"
FEATURE_IMPORTANCE_FILE = (
    REPORTS_DIR / "dip_ai_ncg_ablation_feature_importance.csv"
)

DISCLAIMER = (
    "This ablation evaluates external NCG cancer-driver label reproduction, "
    "not recurrence, treatment response, or clinical decision-making."
)

COMPARISON_SPECS = [
    {
        "comparison": "clean_negatives_effect_with_raw_features",
        "from_experiment": "A_random_negatives_raw_features",
        "to_experiment": "B_clean_negatives_raw_features",
    },
    {
        "comparison": "clean_negatives_effect_with_raw_plus_safety",
        "from_experiment": "C_random_negatives_raw_plus_safety_raw",
        "to_experiment": "D_clean_negatives_raw_plus_safety_raw",
    },
    {
        "comparison": "normal_lung_tpm_effect_with_random_negatives",
        "from_experiment": "A_random_negatives_raw_features",
        "to_experiment": "C_random_negatives_raw_plus_safety_raw",
    },
    {
        "comparison": "normal_lung_tpm_effect_with_clean_negatives",
        "from_experiment": "B_clean_negatives_raw_features",
        "to_experiment": "D_clean_negatives_raw_plus_safety_raw",
    },
    {
        "comparison": "derived_scores_effect_with_clean_negatives",
        "from_experiment": "D_clean_negatives_raw_plus_safety_raw",
        "to_experiment": "E_clean_negatives_derived_scores",
    },
    {
        "comparison": "curated_knowledge_effect_with_clean_negatives",
        "from_experiment": "E_clean_negatives_derived_scores",
        "to_experiment": "F_clean_negatives_knowledge_augmented",
    },
]

DELTA_METRICS = [
    "balanced_accuracy",
    "f1_score",
    "mcc",
    "roc_auc",
    "pr_auc",
]


def main() -> None:
    """Load inputs, run all experiments, and save ablation reports."""
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

    target_features = _load_csv(TARGET_FEATURES_FILE)
    gtex_safety_features = _load_csv(GTEX_SAFETY_FEATURES_FILE)
    ranked_targets = _load_csv(RANKED_TARGETS_FILE)
    ncg_labels = _load_csv(NCG_LABELS_FILE)

    experiments = build_ablation_datasets(
        target_features=target_features,
        gtex_safety_features=gtex_safety_features,
        ranked_targets=ranked_targets,
        ncg_labels=ncg_labels,
        negative_ratio=2,
        random_state=42,
    )
    print("Built six ablation datasets. Running stratified 5-fold models...")
    result = run_ablation_study(experiments)

    metrics = metrics_to_dataframe(result)
    feature_importance = feature_importance_to_dataframe(result)
    effect_table = _build_effect_table(metrics)

    metrics.to_csv(METRICS_FILE, index=False)
    feature_importance.to_csv(FEATURE_IMPORTANCE_FILE, index=False)
    REPORT_FILE.write_text(
        _build_report(
            result=result,
            metrics=metrics,
            feature_importance=feature_importance,
            effect_table=effect_table,
        ),
        encoding="utf-8",
    )

    print(f"Status: {result.get('status')}")
    display_columns = [
        "experiment",
        "model_name",
        "balanced_accuracy",
        "f1_score",
        "mcc",
        "roc_auc",
        "pr_auc",
        "is_best_model",
    ]
    print(metrics.loc[:, display_columns].round(4).to_string(index=False))
    for warning in result.get("warnings", []):
        print(f"WARNING: {warning}")
    print("Saved files:")
    for path in [METRICS_FILE, REPORT_FILE, FEATURE_IMPORTANCE_FILE]:
        print(path)


def _load_csv(path: Path) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(f"Required input file not found: {path}")
    return pd.read_csv(path, low_memory=False)


def _build_effect_table(metrics: pd.DataFrame) -> pd.DataFrame:
    successful = metrics[metrics["status"] == "OK"].copy()
    rows = []
    for spec in COMPARISON_SPECS:
        before = successful[
            successful["experiment"] == spec["from_experiment"]
        ].set_index("model_name")
        after = successful[
            successful["experiment"] == spec["to_experiment"]
        ].set_index("model_name")
        common_models = before.index.intersection(after.index)
        row = {
            "comparison": spec["comparison"],
            "from_experiment": spec["from_experiment"],
            "to_experiment": spec["to_experiment"],
            "models_compared": int(len(common_models)),
        }
        for metric in DELTA_METRICS:
            row[f"{metric}_delta"] = (
                float(
                    (
                        after.loc[common_models, metric]
                        - before.loc[common_models, metric]
                    ).mean()
                )
                if len(common_models)
                else float("nan")
            )
        rows.append(row)
    return pd.DataFrame(rows)


def _build_report(
    result: dict,
    metrics: pd.DataFrame,
    feature_importance: pd.DataFrame,
    effect_table: pd.DataFrame,
) -> str:
    lines = [
        "DIP-AI NCG Scientific Ablation Study",
        "====================================",
        DISCLAIMER,
        "",
        f"Status: {result.get('status')}",
        f"Evaluation: {result.get('evaluation_strategy')}",
        (
            "Best-model rule: highest out-of-fold ROC-AUC within each experiment; "
            "F1 is the tie-breaker."
        ),
        "",
        "Experiment Datasets",
        "-------------------",
    ]

    for summary in result.get("experiments", []):
        lines.extend(
            [
                f"{summary['experiment_label']}",
                f"  Positives: {summary['positive_genes']}",
                f"  Sampled negatives: {summary['negative_genes']}",
                f"  Eligible negative pool: {summary['negative_pool_genes']}",
                f"  Features ({len(summary['feature_columns'])}): "
                f"{', '.join(summary['feature_columns'])}",
            ]
        )

    lines.extend(["", "Metrics", "-------"])
    successful = metrics[metrics["status"] == "OK"].copy()
    if successful.empty:
        lines.append("No successful model metrics were produced.")
    else:
        metric_columns = [
            "experiment",
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

    lines.extend(["", "Aggregate Out-of-Fold Confusion Matrices", "-----------------------------------------"])
    if successful.empty:
        lines.append("No confusion matrices were produced.")
    else:
        for _, row in successful.iterrows():
            lines.append(
                f"{row['experiment']} / {row['model_name']}: "
                f"[[{int(row['tn'])}, {int(row['fp'])}], "
                f"[{int(row['fn'])}, {int(row['tp'])}]]"
            )

    lines.extend(["", "Best Model per Experiment", "-------------------------"])
    best_models = successful[successful["is_best_model"] == True]  # noqa: E712
    if best_models.empty:
        lines.append("No best models were selected.")
    else:
        for _, row in best_models.iterrows():
            lines.append(
                f"{row['experiment_label']}: {row['model_name']} "
                f"(ROC-AUC={row['roc_auc']:.4f}, F1={row['f1_score']:.4f}, "
                f"MCC={row['mcc']:.4f})"
            )

    lines.extend(["", "Paired Mean Effects Across Models", "---------------------------------"])
    if effect_table.empty:
        lines.append("No paired effects were computed.")
    else:
        effect_columns = [
            "comparison",
            "balanced_accuracy_delta",
            "f1_score_delta",
            "mcc_delta",
            "roc_auc_delta",
            "pr_auc_delta",
        ]
        lines.append(
            effect_table.loc[:, effect_columns].round(4).to_string(index=False)
        )
        lines.append(
            "Positive deltas mean the second experiment performed better. "
            "Each delta is averaged across matching model types."
        )

    lines.extend(["", "Top Features of Each Best Model", "-------------------------------"])
    if best_models.empty or feature_importance.empty:
        lines.append("No feature importances were produced.")
    else:
        for _, best_row in best_models.iterrows():
            rows = feature_importance[
                (feature_importance["experiment"] == best_row["experiment"])
                & (feature_importance["model_name"] == best_row["model_name"])
            ].sort_values("rank").head(5)
            lines.append(
                f"{best_row['experiment']} / {best_row['model_name']}:"
            )
            for _, importance_row in rows.iterrows():
                lines.append(
                    f"- {importance_row['feature_name']}: "
                    f"{importance_row['importance']:.6g}"
                )

    lines.extend(["", "Interpretation", "--------------"])
    lines.extend(_interpret_effects(effect_table))

    leakage_warning = _derived_or_knowledge_warning(effect_table)
    lines.extend(["", "Scientific Warning", "------------------", leakage_warning, ""])

    benchmark_warnings = result.get("warnings", [])
    if benchmark_warnings:
        lines.extend(["Model Warnings", "--------------"])
        lines.extend(f"- {warning}" for warning in benchmark_warnings)
        lines.append("")

    return "\n".join(lines)


def _interpret_effects(effect_table: pd.DataFrame) -> list[str]:
    effect_lookup = effect_table.set_index("comparison")

    def describe(comparison: str) -> str:
        if comparison not in effect_lookup.index:
            return "not available"
        row = effect_lookup.loc[comparison]
        return (
            f"mean ΔROC-AUC={row['roc_auc_delta']:+.4f}, "
            f"ΔF1={row['f1_score_delta']:+.4f}, "
            f"ΔMCC={row['mcc_delta']:+.4f}"
        )

    return [
        (
            "- Effect of clean negatives: with raw features, "
            f"{describe('clean_negatives_effect_with_raw_features')}; with "
            "raw plus normal lung TPM, "
            f"{describe('clean_negatives_effect_with_raw_plus_safety')}. "
            "A gain here reflects the negative-selection rule and may mean the "
            "clean negatives are easier to separate."
        ),
        (
            "- Effect of raw safety feature normal_lung_tpm: with random "
            f"negatives, {describe('normal_lung_tpm_effect_with_random_negatives')}; "
            "with clean negatives, "
            f"{describe('normal_lung_tpm_effect_with_clean_negatives')}."
        ),
        (
            "- Effect of derived ranking/safety scores on the fixed clean "
            f"dataset: {describe('derived_scores_effect_with_clean_negatives')}."
        ),
        (
            "- Effect of curated knowledge features on the same fixed clean "
            f"dataset: {describe('curated_knowledge_effect_with_clean_negatives')}."
        ),
    ]


def _derived_or_knowledge_warning(effect_table: pd.DataFrame) -> str:
    if effect_table.empty:
        return (
            "WARNING: Effects could not be computed; do not interpret the "
            "ablation as evidence of independent biological signal."
        )

    lookup = effect_table.set_index("comparison")

    def delta(comparison: str) -> float:
        if comparison not in lookup.index:
            return float("nan")
        return float(lookup.loc[comparison, "roc_auc_delta"])

    safety_delta = delta("normal_lung_tpm_effect_with_clean_negatives")
    derived_delta = delta("derived_scores_effect_with_clean_negatives")
    knowledge_delta = delta("curated_knowledge_effect_with_clean_negatives")
    derived_or_knowledge = max(derived_delta, knowledge_delta)

    if (
        pd.notna(derived_or_knowledge)
        and derived_or_knowledge > max(safety_delta, 0.02)
    ):
        dominant_family = (
            "derived ranking/safety scores"
            if derived_delta >= knowledge_delta
            else "curated knowledge features"
        )
        return (
            f"WARNING: The largest clean-dataset ROC-AUC increase occurs after "
            f"adding {dominant_family} (derived Δ={derived_delta:+.4f}, "
            f"knowledge Δ={knowledge_delta:+.4f}, raw safety "
            f"Δ={safety_delta:+.4f}). Performance is therefore driven mainly "
            "by derived or curated information and must not be interpreted as "
            "independent validation of raw biological signal."
        )

    return (
        "No dominant post-derived_scores or post-knowledge_augmented ROC-AUC "
        "increase was detected under the predefined >0.02 comparison rule. "
        "This still does not establish clinical validity."
    )


if __name__ == "__main__":
    main()
