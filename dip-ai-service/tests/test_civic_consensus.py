"""Tests for CIViC labels and NCG+CIViC consensus benchmarking."""

from pathlib import Path

import pandas as pd
import pytest

from app.data.civic_label_builder import (
    build_civic_external_labels,
    clean_gene_symbol,
    detect_civic_gene_column,
)
from app.models.consensus_external_labels import (
    build_consensus_external_labels,
)
from app.models.consensus_gene_classifier import (
    CONSENSUS_FEATURES,
    build_consensus_classifier_dataset,
    train_evaluate_consensus_classifier,
)


def test_civic_column_detection_handles_current_exports() -> None:
    gene_summaries = pd.DataFrame(
        {
            "feature_type": ["Gene", "Fusion"],
            "name": ["TP53", "EML4::ALK"],
            "five_prime_gene_name": [pd.NA, "EML4"],
        }
    )
    clinical = pd.DataFrame(
        {
            "variant_origin": ["Somatic"],
            "molecular_profile": ["TP53 R175H"],
        }
    )

    assert detect_civic_gene_column(gene_summaries) == "name"
    assert detect_civic_gene_column(clinical) == "molecular_profile"
    assert clean_gene_symbol("  egfr  ") == "EGFR"
    assert clean_gene_symbol(pd.NA) == ""


def test_civic_builder_extracts_genes_and_fusion_partners(
    tmp_path: Path,
) -> None:
    gene_summaries = pd.DataFrame(
        {
            "feature_type": ["Gene", "Gene", "Gene", "Fusion", "Factor"],
            "name": ["TP53", "ALK", "KRAS", "EML4::ALK", "TMB"],
            "five_prime_gene_name": [pd.NA, pd.NA, pd.NA, "EML4", pd.NA],
            "three_prime_gene_name": [pd.NA, pd.NA, pd.NA, "ALK", pd.NA],
        }
    )
    clinical = pd.DataFrame(
        {
            "molecular_profile": [
                "TP53 R175H",
                "EML4::ALK Fusion",
            ]
        }
    )
    gene_summaries.to_csv(
        tmp_path / "nightly-GeneSummaries.tsv",
        sep="\t",
        index=False,
    )
    clinical.to_csv(
        tmp_path / "nightly-ClinicalEvidenceSummaries.tsv",
        sep="\t",
        index=False,
    )

    labels = build_civic_external_labels(tmp_path)

    assert set(labels["gene_name"]) == {"TP53", "ALK", "KRAS", "EML4"}
    assert "TMB" not in set(labels["gene_name"])
    scores = labels.set_index("gene_name")["evidence_score"].to_dict()
    assert scores == {"ALK": 1.0, "EML4": 1.0, "KRAS": 0.9, "TP53": 1.0}


def test_consensus_label_rules() -> None:
    ranked = pd.DataFrame({"gene_name": ["A", "B", "C", "D"]})
    ncg = pd.DataFrame(
        {
            "gene_name": ["A", "B"],
            "evidence_score": [1.0, 1.0],
            "label": [1, 1],
        }
    )
    civic = pd.DataFrame(
        {
            "gene_name": ["B", "C"],
            "evidence_score": [0.9, 1.0],
            "label": [1, 1],
        }
    )

    consensus = build_consensus_external_labels(ranked, ncg, civic)
    by_gene = consensus.set_index("gene_name")

    assert by_gene.loc["A", "consensus_confidence"] == "single_source_positive"
    assert by_gene.loc["B", "consensus_confidence"] == "high_confidence_positive"
    assert by_gene.loc["C", "consensus_confidence"] == "single_source_positive"
    assert by_gene.loc["D", "consensus_confidence"] == "negative_candidate"
    assert by_gene.loc["B", "high_confidence_label"] == 1
    assert by_gene.loc["D", "high_confidence_label"] == 0
    assert pd.isna(by_gene.loc["A", "high_confidence_label"])


def test_high_confidence_dataset_excludes_single_source_positives() -> None:
    ranked = pd.DataFrame({"gene_name": ["A", "B", "C", "D", "E"]})
    ncg = pd.DataFrame({"gene_name": ["A", "B"], "label": [1, 1]})
    civic = pd.DataFrame({"gene_name": ["B", "C"], "label": [1, 1]})
    consensus = build_consensus_external_labels(ranked, ncg, civic)
    target_features = pd.DataFrame(
        {
            "gene_name": ranked["gene_name"],
            **{
                feature: [float(index + offset) for index in range(5)]
                for offset, feature in enumerate(CONSENSUS_FEATURES[:-1])
            },
        }
    )
    gtex = pd.DataFrame(
        {
            "gene_name": ranked["gene_name"],
            "normal_lung_tpm": [1.0, 2.0, 3.0, 4.0, 5.0],
            "safety_score": [0.75] * 5,
        }
    )

    high_confidence = build_consensus_classifier_dataset(
        target_features,
        gtex,
        consensus,
        label_mode="high_confidence",
        negative_ratio=2,
        random_state=42,
    )

    assert set(high_confidence["gene_name"]) == {"B", "D", "E"}
    assert int((high_confidence["external_label"] == 1).sum()) == 1
    assert int((high_confidence["external_label"] == 0).sum()) == 2

    with pytest.raises(ValueError, match="Forbidden leakage-prone features"):
        train_evaluate_consensus_classifier(
            high_confidence,
            [*CONSENSUS_FEATURES, "ranking_score_v4"],
            label_mode="high_confidence",
        )
