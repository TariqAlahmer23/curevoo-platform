"""Safety tests for the leakage-minimized NCG classifier."""

import pandas as pd
import pytest

from app.models.leakage_minimized_classifier import (
    ALLOWED_FEATURES,
    FORBIDDEN_FEATURES,
    build_leakage_minimized_dataset,
    train_evaluate_leakage_minimized_classifier,
)


def _input_tables() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    target_feature_names = ALLOWED_FEATURES[:-1]
    target_features = pd.DataFrame(
        {
            "gene_name": ["a", "B", "C", "D", "E", "F"],
            **{
                feature: [float(index + offset) for index in range(6)]
                for offset, feature in enumerate(target_feature_names)
            },
            "ranking_score_v4": [0.9] * 6,
            "candidate_score_v2_features": [0.8] * 6,
        }
    )
    gtex_safety_features = pd.DataFrame(
        {
            "gene_name": ["A", "B", "C", "D", "E"],
            "normal_lung_tpm": [1.0, 2.0, 3.0, 4.0, 5.0],
            "safety_score": [0.75] * 5,
        }
    )
    ncg_labels = pd.DataFrame(
        {
            "gene_name": ["A", "B"],
            "label": [1, 1],
        }
    )
    return target_features, gtex_safety_features, ncg_labels


def test_dataset_uses_only_allowed_features_and_samples_negatives() -> None:
    target_features, gtex_safety_features, ncg_labels = _input_tables()

    dataset = build_leakage_minimized_dataset(
        target_features,
        gtex_safety_features,
        ncg_labels,
        negative_ratio=2,
        random_state=42,
    )

    assert dataset.columns.tolist() == [
        "gene_name",
        *ALLOWED_FEATURES,
        "external_label",
        "label_source",
    ]
    assert set(dataset.columns).isdisjoint(FORBIDDEN_FEATURES)
    assert int((dataset["external_label"] == 1).sum()) == 2
    assert int((dataset["external_label"] == 0).sum()) == 4
    assert set(dataset.loc[dataset["external_label"] == 1, "gene_name"]) == {
        "A",
        "B",
    }
    assert dataset.loc[dataset["gene_name"] == "F", "normal_lung_tpm"].isna().all()


def test_forbidden_feature_is_rejected() -> None:
    target_features, gtex_safety_features, ncg_labels = _input_tables()
    dataset = build_leakage_minimized_dataset(
        target_features,
        gtex_safety_features,
        ncg_labels,
    )

    with pytest.raises(ValueError, match="Forbidden leakage-prone features"):
        train_evaluate_leakage_minimized_classifier(
            dataset,
            [*ALLOWED_FEATURES, "ranking_score_v4"],
        )


def test_non_allowed_feature_is_rejected() -> None:
    target_features, gtex_safety_features, ncg_labels = _input_tables()
    dataset = build_leakage_minimized_dataset(
        target_features,
        gtex_safety_features,
        ncg_labels,
    )
    dataset["candidate_score_v2_features"] = 0.5

    with pytest.raises(ValueError, match="ALLOWED_FEATURES"):
        train_evaluate_leakage_minimized_classifier(
            dataset,
            [*ALLOWED_FEATURES, "candidate_score_v2_features"],
        )


def test_training_stops_when_class_counts_are_too_small() -> None:
    target_features, gtex_safety_features, ncg_labels = _input_tables()
    dataset = build_leakage_minimized_dataset(
        target_features,
        gtex_safety_features,
        ncg_labels,
    )

    result = train_evaluate_leakage_minimized_classifier(
        dataset,
        ALLOWED_FEATURES,
    )

    assert result["status"] == "SKIPPED"
    assert result["metrics"] == []
    assert any("Insufficient NCG positives" in item for item in result["warnings"])
    assert any("Insufficient sampled negatives" in item for item in result["warnings"])
