"""Dataset and interpretation tests for the NCG ablation study."""

import pandas as pd

from app.models.ablation_study import (
    DERIVED_SCORE_FEATURES,
    EXPERIMENT_CONFIGS,
    KNOWLEDGE_AUGMENTED_FEATURES,
    RAW_FEATURES,
    RAW_PLUS_SAFETY_RAW_FEATURES,
    build_ablation_datasets,
)
from scripts.run_ncg_ablation_study import _derived_or_knowledge_warning


def _synthetic_inputs() -> tuple[
    pd.DataFrame,
    pd.DataFrame,
    pd.DataFrame,
    pd.DataFrame,
]:
    gene_names = [f"GENE{index}" for index in range(10)]
    target_features = pd.DataFrame(
        {
            "gene_name": gene_names,
            **{
                feature: [float(index + offset) for index in range(10)]
                for offset, feature in enumerate(
                    [
                        *RAW_FEATURES,
                        "mutation_frequency_score",
                        "expression_score",
                        "protein_impact_score",
                    ]
                )
            },
        }
    )
    gtex = pd.DataFrame(
        {
            "gene_name": gene_names[:-1],
            "normal_lung_tpm": [float(index) for index in range(9)],
            "safety_score": [0.75] * 9,
        }
    )
    ranked = pd.DataFrame(
        {
            "gene_name": gene_names,
            "ranking_score_v3": [0.2] * 10,
            "ranking_score_v4": [0.2] * 8 + [0.5, 0.2],
            "safety_score": [0.75] * 10,
            "safety_penalty": [0.05] * 10,
            "luad_relevance_score": [0.2] * 10,
            "targetability_score": [0.2] * 10,
            "dormancy_evidence_score": [0.2] * 10,
            "passenger_penalty": [0.0] * 9 + [0.35],
            "evidence_tier_v6": ["Tier_5_Low_Evidence_Target"] * 10,
            "target_category_v6": ["General Candidate"] * 10,
        }
    )
    ncg = pd.DataFrame({"gene_name": ["GENE0", "gene1"], "label": [1, 1]})
    return target_features, gtex, ranked, ncg


def test_ablation_datasets_share_samples_within_strategy() -> None:
    target_features, gtex, ranked, ncg = _synthetic_inputs()
    experiments = build_ablation_datasets(
        target_features,
        gtex,
        ranked,
        ncg,
        negative_ratio=2,
        random_state=42,
    )

    assert list(experiments) == list(EXPERIMENT_CONFIGS)
    assert all(item["positive_count"] == 2 for item in experiments.values())
    assert all(item["negative_count"] == 4 for item in experiments.values())

    random_a = set(
        experiments["A_random_negatives_raw_features"]["dataset"]["gene_name"]
    )
    random_c = set(
        experiments[
            "C_random_negatives_raw_plus_safety_raw"
        ]["dataset"]["gene_name"]
    )
    assert random_a == random_c

    clean_names = [
        "B_clean_negatives_raw_features",
        "D_clean_negatives_raw_plus_safety_raw",
        "E_clean_negatives_derived_scores",
        "F_clean_negatives_knowledge_augmented",
    ]
    clean_sets = [
        set(experiments[name]["dataset"]["gene_name"]) for name in clean_names
    ]
    assert all(gene_set == clean_sets[0] for gene_set in clean_sets[1:])


def test_ablation_feature_families_are_exact() -> None:
    assert EXPERIMENT_CONFIGS[
        "A_random_negatives_raw_features"
    ]["feature_columns"] == RAW_FEATURES
    assert EXPERIMENT_CONFIGS[
        "B_clean_negatives_raw_features"
    ]["feature_columns"] == RAW_FEATURES
    assert EXPERIMENT_CONFIGS[
        "C_random_negatives_raw_plus_safety_raw"
    ]["feature_columns"] == RAW_PLUS_SAFETY_RAW_FEATURES
    assert EXPERIMENT_CONFIGS[
        "D_clean_negatives_raw_plus_safety_raw"
    ]["feature_columns"] == RAW_PLUS_SAFETY_RAW_FEATURES
    assert EXPERIMENT_CONFIGS[
        "E_clean_negatives_derived_scores"
    ]["feature_columns"] == DERIVED_SCORE_FEATURES
    assert EXPERIMENT_CONFIGS[
        "F_clean_negatives_knowledge_augmented"
    ]["feature_columns"] == KNOWLEDGE_AUGMENTED_FEATURES


def test_warning_fires_when_derived_scores_dominate() -> None:
    effect_table = pd.DataFrame(
        [
            {
                "comparison": "normal_lung_tpm_effect_with_clean_negatives",
                "roc_auc_delta": 0.01,
            },
            {
                "comparison": "derived_scores_effect_with_clean_negatives",
                "roc_auc_delta": 0.15,
            },
            {
                "comparison": "curated_knowledge_effect_with_clean_negatives",
                "roc_auc_delta": 0.005,
            },
        ]
    )

    warning = _derived_or_knowledge_warning(effect_table)

    assert warning.startswith("WARNING:")
    assert "derived ranking/safety scores" in warning
