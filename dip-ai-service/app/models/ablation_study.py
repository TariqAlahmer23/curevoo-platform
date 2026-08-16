"""NCG ablation study for negative sampling and feature-family effects."""

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


RAW_FEATURES = [
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
]

RAW_PLUS_SAFETY_RAW_FEATURES = [
    *RAW_FEATURES,
    "normal_lung_tpm",
]

DERIVED_SCORE_FEATURES = [
    *RAW_PLUS_SAFETY_RAW_FEATURES,
    "mutation_frequency_score",
    "expression_score",
    "protein_impact_score",
    "ranking_score_v3",
    "ranking_score_v4",
    "safety_score",
    "safety_penalty",
]

KNOWLEDGE_AUGMENTED_FEATURES = [
    *DERIVED_SCORE_FEATURES,
    "luad_relevance_score",
    "targetability_score",
    "dormancy_evidence_score",
    "passenger_penalty",
]

EXPERIMENT_CONFIGS = {
    "A_random_negatives_raw_features": {
        "label": "A) random_negatives + raw_features",
        "negative_strategy": "random_negatives",
        "feature_set": "raw_features",
        "feature_columns": RAW_FEATURES,
    },
    "B_clean_negatives_raw_features": {
        "label": "B) clean_negatives + raw_features",
        "negative_strategy": "clean_negatives",
        "feature_set": "raw_features",
        "feature_columns": RAW_FEATURES,
    },
    "C_random_negatives_raw_plus_safety_raw": {
        "label": "C) random_negatives + raw_plus_safety_raw",
        "negative_strategy": "random_negatives",
        "feature_set": "raw_plus_safety_raw",
        "feature_columns": RAW_PLUS_SAFETY_RAW_FEATURES,
    },
    "D_clean_negatives_raw_plus_safety_raw": {
        "label": "D) clean_negatives + raw_plus_safety_raw",
        "negative_strategy": "clean_negatives",
        "feature_set": "raw_plus_safety_raw",
        "feature_columns": RAW_PLUS_SAFETY_RAW_FEATURES,
    },
    "E_clean_negatives_derived_scores": {
        "label": "E) clean_negatives + derived_scores",
        "negative_strategy": "clean_negatives",
        "feature_set": "derived_scores",
        "feature_columns": DERIVED_SCORE_FEATURES,
    },
    "F_clean_negatives_knowledge_augmented": {
        "label": "F) clean_negatives + knowledge_augmented",
        "negative_strategy": "clean_negatives",
        "feature_set": "knowledge_augmented",
        "feature_columns": KNOWLEDGE_AUGMENTED_FEATURES,
    },
}

LABEL_COLUMN = "external_label"
RANDOM_STATE = 42
N_SPLITS = 5
MIN_POSITIVES = 20
MIN_NEGATIVES = 20
CLEAN_EVIDENCE_TIER = "Tier_5_Low_Evidence_Target"
CLEAN_TARGET_CATEGORY = "General Candidate"

METRIC_COLUMNS = [
    "experiment",
    "experiment_label",
    "negative_strategy",
    "feature_set",
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
    "positive_genes",
    "negative_genes",
    "total_genes",
    "is_best_model",
    "warning",
]

FEATURE_IMPORTANCE_COLUMNS = [
    "experiment",
    "experiment_label",
    "negative_strategy",
    "feature_set",
    "model_name",
    "feature_name",
    "importance",
    "abs_importance",
    "rank",
]


def build_ablation_datasets(
    target_features: pd.DataFrame,
    gtex_safety_features: pd.DataFrame,
    ranked_targets: pd.DataFrame,
    ncg_labels: pd.DataFrame,
    negative_ratio: int = 2,
    random_state: int = 42,
) -> dict[str, dict[str, Any]]:
    """
    Build six ablation datasets with shared samples within each strategy.

    A/C use the same randomly sampled non-NCG genes. B/D/E/F use the same
    clean-negative genes selected by the requested V6 ranking criteria.
    """
    if not isinstance(negative_ratio, int) or isinstance(negative_ratio, bool):
        raise ValueError("negative_ratio must be a positive integer.")
    if negative_ratio <= 0:
        raise ValueError("negative_ratio must be greater than zero.")

    target_columns = [
        "gene_name",
        *RAW_FEATURES,
        "mutation_frequency_score",
        "expression_score",
        "protein_impact_score",
    ]
    gtex_columns = ["gene_name", "normal_lung_tpm"]
    ranked_columns = [
        "gene_name",
        "ranking_score_v3",
        "ranking_score_v4",
        "safety_score",
        "safety_penalty",
        "luad_relevance_score",
        "targetability_score",
        "dormancy_evidence_score",
        "passenger_penalty",
        "evidence_tier_v6",
        "target_category_v6",
    ]
    _require_columns(target_features, target_columns, "target_features")
    _require_columns(gtex_safety_features, gtex_columns, "gtex_safety_features")
    _require_columns(ranked_targets, ranked_columns, "ranked_targets")
    _require_columns(ncg_labels, ["gene_name"], "ncg_labels")

    targets = _prepare_unique_gene_table(
        target_features.loc[:, target_columns],
        "target_features",
    )
    ranked = _prepare_unique_gene_table(
        ranked_targets.loc[:, ranked_columns],
        "ranked_targets",
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
        ranked,
        on="gene_name",
        how="left",
        validate="one_to_one",
    )

    all_feature_columns = list(
        dict.fromkeys(
            [
                *KNOWLEDGE_AUGMENTED_FEATURES,
                "evidence_tier_v6",
                "target_category_v6",
            ]
        )
    )
    numeric_columns = [
        column
        for column in all_feature_columns
        if column not in {"evidence_tier_v6", "target_category_v6"}
    ]
    for column in numeric_columns:
        universe[column] = pd.to_numeric(universe[column], errors="coerce")

    ncg_gene_names = set(
        _normalize_gene_names(ncg_labels["gene_name"]).dropna().astype(str)
    )
    is_positive = universe["gene_name"].isin(ncg_gene_names)
    positives = universe.loc[is_positive].copy()
    random_negative_pool = universe.loc[~is_positive].copy()

    clean_negative_mask = (
        ~is_positive
        & universe["evidence_tier_v6"].astype(str).eq(CLEAN_EVIDENCE_TIER)
        & universe["target_category_v6"].astype(str).eq(CLEAN_TARGET_CATEGORY)
        & universe["ranking_score_v4"].lt(0.40)
        & universe["passenger_penalty"].eq(0)
    )
    clean_negative_pool = universe.loc[clean_negative_mask].copy()

    maximum_negatives = negative_ratio * len(positives)
    selected_negatives = {
        "random_negatives": _sample_negatives(
            random_negative_pool,
            maximum_negatives,
            random_state,
        ),
        "clean_negatives": _sample_negatives(
            clean_negative_pool,
            maximum_negatives,
            random_state,
        ),
    }

    datasets: dict[str, dict[str, Any]] = {}
    for experiment_name, config in EXPERIMENT_CONFIGS.items():
        strategy = str(config["negative_strategy"])
        feature_columns = list(config["feature_columns"])
        experiment_dataset = _assemble_labeled_dataset(
            positives=positives,
            negatives=selected_negatives[strategy],
            feature_columns=feature_columns,
            negative_strategy=strategy,
        )
        datasets[experiment_name] = {
            "experiment": experiment_name,
            "experiment_label": config["label"],
            "negative_strategy": strategy,
            "feature_set": config["feature_set"],
            "feature_columns": feature_columns,
            "dataset": experiment_dataset,
            "positive_count": int(
                (experiment_dataset[LABEL_COLUMN] == 1).sum()
            ),
            "negative_count": int(
                (experiment_dataset[LABEL_COLUMN] == 0).sum()
            ),
            "negative_pool_count": int(
                len(
                    random_negative_pool
                    if strategy == "random_negatives"
                    else clean_negative_pool
                )
            ),
        }

    _validate_shared_gene_sets(datasets)
    return datasets


def run_ablation_study(
    experiments: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    """Train and evaluate all ablation experiments."""
    expected_experiments = list(EXPERIMENT_CONFIGS)
    missing_experiments = [
        experiment
        for experiment in expected_experiments
        if experiment not in experiments
    ]
    if missing_experiments:
        raise ValueError(
            f"Missing required ablation experiments: {missing_experiments}"
        )

    all_metrics: list[dict[str, Any]] = []
    all_importances: list[dict[str, Any]] = []
    all_warnings: list[str] = []
    experiment_summaries: list[dict[str, Any]] = []

    for experiment_name in expected_experiments:
        experiment = experiments[experiment_name]
        result = _evaluate_experiment(experiment)
        all_metrics.extend(result["metrics"])
        all_importances.extend(result["feature_importance"])
        all_warnings.extend(result["warnings"])
        experiment_summaries.append(
            {
                "experiment": experiment_name,
                "experiment_label": experiment["experiment_label"],
                "negative_strategy": experiment["negative_strategy"],
                "feature_set": experiment["feature_set"],
                "positive_genes": experiment["positive_count"],
                "negative_genes": experiment["negative_count"],
                "negative_pool_genes": experiment["negative_pool_count"],
                "feature_columns": experiment["feature_columns"],
            }
        )

    _mark_best_models(all_metrics)
    completed_experiments = {
        row["experiment"]
        for row in all_metrics
        if row["status"] == "OK"
    }
    return {
        "status": (
            "COMPLETED"
            if len(completed_experiments) == len(expected_experiments)
            else "PARTIAL"
        ),
        "metrics": all_metrics,
        "feature_importance": all_importances,
        "warnings": all_warnings,
        "experiments": experiment_summaries,
        "evaluation_strategy": f"stratified_{N_SPLITS}_fold_cross_validation",
        "cv_summary": {
            "n_splits": N_SPLITS,
            "shuffle": True,
            "random_state": RANDOM_STATE,
        },
    }


def metrics_to_dataframe(result: dict[str, Any]) -> pd.DataFrame:
    """Convert ablation metrics to a stable CSV-ready dataframe."""
    return pd.DataFrame(result.get("metrics", [])).reindex(columns=METRIC_COLUMNS)


def feature_importance_to_dataframe(
    result: dict[str, Any],
) -> pd.DataFrame:
    """Convert ablation feature importances to a stable CSV-ready dataframe."""
    return pd.DataFrame(result.get("feature_importance", [])).reindex(
        columns=FEATURE_IMPORTANCE_COLUMNS
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


def _sample_negatives(
    negative_pool: pd.DataFrame,
    maximum_negatives: int,
    random_state: int,
) -> pd.DataFrame:
    if len(negative_pool) <= maximum_negatives:
        return negative_pool.copy()
    return negative_pool.sample(
        n=maximum_negatives,
        random_state=random_state,
    ).copy()


def _assemble_labeled_dataset(
    positives: pd.DataFrame,
    negatives: pd.DataFrame,
    feature_columns: list[str],
    negative_strategy: str,
) -> pd.DataFrame:
    positive_rows = positives.loc[:, ["gene_name", *feature_columns]].copy()
    negative_rows = negatives.loc[:, ["gene_name", *feature_columns]].copy()
    positive_rows[LABEL_COLUMN] = 1
    positive_rows["label_source"] = "NCG_positive"
    negative_rows[LABEL_COLUMN] = 0
    negative_rows["label_source"] = (
        "non_NCG_random_negative"
        if negative_strategy == "random_negatives"
        else "non_NCG_clean_negative"
    )
    dataset = pd.concat(
        [positive_rows, negative_rows],
        ignore_index=True,
    )
    return dataset.sort_values(
        [LABEL_COLUMN, "gene_name"],
        ascending=[False, True],
    ).reset_index(drop=True)


def _validate_shared_gene_sets(
    datasets: dict[str, dict[str, Any]],
) -> None:
    random_gene_sets = [
        set(datasets[name]["dataset"]["gene_name"])
        for name in [
            "A_random_negatives_raw_features",
            "C_random_negatives_raw_plus_safety_raw",
        ]
    ]
    if random_gene_sets[0] != random_gene_sets[1]:
        raise RuntimeError("Random-negative experiments do not share gene sets.")

    clean_names = [
        "B_clean_negatives_raw_features",
        "D_clean_negatives_raw_plus_safety_raw",
        "E_clean_negatives_derived_scores",
        "F_clean_negatives_knowledge_augmented",
    ]
    clean_gene_sets = [
        set(datasets[name]["dataset"]["gene_name"]) for name in clean_names
    ]
    if any(gene_set != clean_gene_sets[0] for gene_set in clean_gene_sets[1:]):
        raise RuntimeError("Clean-negative experiments do not share gene sets.")


def _evaluate_experiment(
    experiment: dict[str, Any],
) -> dict[str, Any]:
    dataset = experiment["dataset"]
    feature_columns = list(experiment["feature_columns"])
    _validate_training_dataset(dataset, feature_columns)

    positive_count = int((dataset[LABEL_COLUMN] == 1).sum())
    negative_count = int((dataset[LABEL_COLUMN] == 0).sum())
    if positive_count < MIN_POSITIVES or negative_count < MIN_NEGATIVES:
        issues = []
        if positive_count < MIN_POSITIVES:
            issues.append(
                f"{experiment['experiment']}: only {positive_count} positives; "
                f"minimum is {MIN_POSITIVES}."
            )
        if negative_count < MIN_NEGATIVES:
            issues.append(
                f"{experiment['experiment']}: only {negative_count} negatives; "
                f"minimum is {MIN_NEGATIVES}."
            )
        return {"metrics": [], "feature_importance": [], "warnings": issues}

    X = dataset.loc[:, feature_columns].apply(pd.to_numeric, errors="coerce")
    y = dataset[LABEL_COLUMN].astype(int)
    all_missing = [feature for feature in feature_columns if X[feature].isna().all()]
    if all_missing:
        raise ValueError(
            f"{experiment['experiment']} has all-missing features: {all_missing}"
        )

    model_pipelines, model_warnings = _build_model_pipelines()
    metrics: list[dict[str, Any]] = []
    importances: list[dict[str, Any]] = []

    for model_name, pipeline in model_pipelines:
        try:
            oof_labels, oof_probabilities = _out_of_fold_predictions(
                pipeline,
                X,
                y,
            )
            metrics.append(
                _calculate_metrics(
                    experiment=experiment,
                    model_name=model_name,
                    y_true=y.to_numpy(),
                    y_pred=oof_labels,
                    y_probability=oof_probabilities,
                )
            )

            fitted_pipeline = clone(pipeline)
            _fit_pipeline(fitted_pipeline, X, y)
            importances.extend(
                _extract_feature_importance(
                    experiment=experiment,
                    model_name=model_name,
                    pipeline=fitted_pipeline,
                    feature_columns=feature_columns,
                )
            )
        except Exception as exc:  # pragma: no cover - defensive model barrier
            warning = (
                f"{experiment['experiment']} / {model_name} failed: {exc}"
            )
            model_warnings.append(warning)
            metrics.append(
                _failed_metric_row(
                    experiment=experiment,
                    model_name=model_name,
                    y=y,
                    warning=warning,
                )
            )

    return {
        "metrics": metrics,
        "feature_importance": importances,
        "warnings": model_warnings,
    }


def _validate_training_dataset(
    dataset: pd.DataFrame,
    feature_columns: list[str],
) -> None:
    if not feature_columns:
        raise ValueError("An ablation experiment has no feature columns.")
    _require_columns(
        dataset,
        ["gene_name", LABEL_COLUMN, *feature_columns],
        "experiment dataset",
    )
    labels = pd.to_numeric(dataset[LABEL_COLUMN], errors="coerce")
    if labels.isna().any() or not labels.isin([0, 1]).all():
        raise ValueError("external_label must contain only binary 0/1 values.")
    if dataset["gene_name"].duplicated().any():
        raise ValueError("Experiment dataset contains duplicate gene names.")


def _build_model_pipelines() -> tuple[list[tuple[str, Pipeline]], list[str]]:
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


def _out_of_fold_predictions(
    pipeline: Pipeline,
    X: pd.DataFrame,
    y: pd.Series,
) -> tuple[np.ndarray, np.ndarray]:
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

    return predicted_labels.astype(int), predicted_probabilities


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
    experiment: dict[str, Any],
    model_name: str,
    y_true: np.ndarray,
    y_pred: np.ndarray,
    y_probability: np.ndarray,
) -> dict[str, Any]:
    tn, fp, fn, tp = confusion_matrix(y_true, y_pred, labels=[0, 1]).ravel()
    return {
        "experiment": experiment["experiment"],
        "experiment_label": experiment["experiment_label"],
        "negative_strategy": experiment["negative_strategy"],
        "feature_set": experiment["feature_set"],
        "model_name": model_name,
        "status": "OK",
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "balanced_accuracy": float(
            balanced_accuracy_score(y_true, y_pred)
        ),
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
        "positive_genes": int((y_true == 1).sum()),
        "negative_genes": int((y_true == 0).sum()),
        "total_genes": int(len(y_true)),
        "is_best_model": False,
        "warning": "",
    }


def _extract_feature_importance(
    experiment: dict[str, Any],
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
            "experiment": experiment["experiment"],
            "experiment_label": experiment["experiment_label"],
            "negative_strategy": experiment["negative_strategy"],
            "feature_set": experiment["feature_set"],
            "model_name": model_name,
            "feature_name": feature_name,
            "importance": float(importance),
            "abs_importance": float(abs(importance)),
        }
        for feature_name, importance in zip(feature_columns, importance_values)
    ]
    rows.sort(key=lambda row: row["abs_importance"], reverse=True)
    for rank, row in enumerate(rows, start=1):
        row["rank"] = rank
    return rows


def _failed_metric_row(
    experiment: dict[str, Any],
    model_name: str,
    y: pd.Series,
    warning: str,
) -> dict[str, Any]:
    return {
        "experiment": experiment["experiment"],
        "experiment_label": experiment["experiment_label"],
        "negative_strategy": experiment["negative_strategy"],
        "feature_set": experiment["feature_set"],
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
        "positive_genes": int((y == 1).sum()),
        "negative_genes": int((y == 0).sum()),
        "total_genes": int(len(y)),
        "is_best_model": False,
        "warning": warning,
    }


def _mark_best_models(metrics: list[dict[str, Any]]) -> None:
    for experiment_name in EXPERIMENT_CONFIGS:
        successful = [
            row
            for row in metrics
            if row["experiment"] == experiment_name and row["status"] == "OK"
        ]
        if not successful:
            continue
        best = max(
            successful,
            key=lambda row: (row["roc_auc"], row["f1_score"]),
        )
        best["is_best_model"] = True
