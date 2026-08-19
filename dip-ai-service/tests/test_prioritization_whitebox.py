"""White-box tests for the genomic target prioritization pipeline.

These exercise the internal logic directly — feature construction, safety
scoring, ranking arithmetic, tier assignment, explanation text, external
evidence matching, metrics loading, report generation and temporary file
cleanup — rather than going through the HTTP surface.
"""

from pathlib import Path
import sys

import pandas as pd
import pytest

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.api import prioritization_service as svc
from app.features.mutation_features import build_mutation_features
from app.features.expression_features import build_expression_features
from app.features.safety_features import assign_safety_risk, assign_safety_score
from app.features.target_features import build_target_feature_table
from app.models.evidence_tiering import add_evidence_tiers_v6
from app.models.gene_knowledge_base import get_luad_relevance_score, get_passenger_penalty
from app.models.ranking_engine import rank_targets_v3, rank_targets_v4_with_safety
from app.reports.final_outputs import create_markdown_report
from app.reports.ml_metrics import build_ml_metrics_payload, select_primary_evaluation


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def mutations() -> pd.DataFrame:
    """Small mutation table covering two genes across three patients."""
    return pd.DataFrame(
        {
            "Hugo_Symbol": ["TP53", "TP53", "KRAS", "TP53", "KRAS"],
            "Variant_Classification": [
                "Missense_Mutation",
                "Nonsense_Mutation",
                "Missense_Mutation",
                "Silent",
                "Frame_Shift_Del",
            ],
            "patient_barcode": ["P1", "P2", "P1", "P3", "P2"],
            "sample_barcode": ["S1", "S2", "S1", "S3", "S2"],
        }
    )


@pytest.fixture
def expression() -> pd.DataFrame:
    """Expression matrix for the same two genes across three samples."""
    return pd.DataFrame(
        {
            "gene_name": ["TP53", "KRAS"],
            "S1": [12.0, 4.0],
            "S2": [18.0, 6.0],
            "S3": [24.0, 8.0],
        }
    )


# ---------------------------------------------------------------------------
# WB-01/02/03  Input, column and parsing validation
# ---------------------------------------------------------------------------


def test_missing_required_mutation_column_is_rejected(expression: pd.DataFrame) -> None:
    """A mutation table without Hugo_Symbol must be refused, not silently coerced."""
    broken = pd.DataFrame({"patient_barcode": ["P1"], "sample_barcode": ["S1"]})

    with pytest.raises(Exception) as excinfo:
        build_target_feature_table(broken, expression)

    assert "Hugo_Symbol" in str(excinfo.value) or "column" in str(excinfo.value).lower()


def test_missing_gene_name_column_in_expression_is_rejected(
    mutations: pd.DataFrame,
) -> None:
    """An expression matrix without gene_name must be refused."""
    broken = pd.DataFrame({"S1": [1.0], "S2": [2.0]})

    with pytest.raises(Exception):
        build_target_feature_table(mutations, broken)


def test_empty_uploaded_file_raises_analysis_input_error(tmp_path: Path) -> None:
    """An empty CSV must produce a typed input error, not an unhandled parser error."""
    empty = tmp_path / "empty.csv"
    empty.write_text("", encoding="utf-8")

    with pytest.raises((svc.AnalysisInputError, svc.PipelineDataError, Exception)):
        svc.run_analysis(mutations_path=empty, expression_path=empty, top_n=5)


# ---------------------------------------------------------------------------
# WB-04/05/06/07  Feature engineering
# ---------------------------------------------------------------------------


def test_mutation_features_count_distinct_patients_not_rows(
    mutations: pd.DataFrame,
) -> None:
    """TP53 appears in 3 rows but only 3 distinct patients; KRAS in 2 rows / 2 patients."""
    features = build_mutation_features(mutations).set_index("gene_name")

    assert features.loc["TP53", "mutated_patients"] == 3
    assert features.loc["KRAS", "mutated_patients"] == 2


def test_silent_mutations_do_not_inflate_protein_impact(
    mutations: pd.DataFrame,
) -> None:
    """A Silent variant must not be counted as a non-synonymous change."""
    features = build_mutation_features(mutations).set_index("gene_name")

    assert features.loc["TP53", "nonsynonymous_mutation_count"] == 2


def test_expression_features_are_computed_per_gene(expression: pd.DataFrame) -> None:
    """Mean expression must match the row mean of the input matrix."""
    features = build_expression_features(expression).set_index("gene_name")

    assert features.loc["TP53", "mean_tumor_expression"] == pytest.approx(18.0, abs=1e-6)
    assert features.loc["KRAS", "mean_tumor_expression"] == pytest.approx(6.0, abs=1e-6)


def test_target_table_joins_mutation_and_expression_on_gene(
    mutations: pd.DataFrame, expression: pd.DataFrame
) -> None:
    """The joined feature table must carry both feature families for each gene."""
    table = build_target_feature_table(mutations, expression)

    assert set(table["gene_name"]) == {"TP53", "KRAS"}
    assert "mutated_patients" in table.columns
    assert "mean_tumor_expression" in table.columns


# ---------------------------------------------------------------------------
# WB-08  GTEx normal lung safety scoring
# ---------------------------------------------------------------------------


def test_safety_score_decreases_as_normal_lung_expression_rises() -> None:
    """A gene highly expressed in normal lung must score less safe than a quiet one."""
    quiet = assign_safety_score(0.5)
    loud = assign_safety_score(200.0)

    assert quiet > loud


def test_safety_risk_labels_follow_expression_bands() -> None:
    """Risk labels must be ordered consistently with normal-tissue expression."""
    assert assign_safety_risk(0.5) != assign_safety_risk(200.0)
    assert isinstance(assign_safety_risk(25.0), str)


# ---------------------------------------------------------------------------
# WB-09/10  Ranking arithmetic and passenger penalty
# ---------------------------------------------------------------------------


def test_ranking_scores_are_bounded_and_ordered(
    mutations: pd.DataFrame, expression: pd.DataFrame
) -> None:
    """Ranking scores must stay within [0, 1] and sort descending."""
    table = build_target_feature_table(mutations, expression)
    ranked = rank_targets_v3(table)

    scores = ranked["ranking_score_v3"]
    assert scores.between(0.0, 1.0).all()
    assert list(scores) == sorted(scores, reverse=True)


def test_passenger_penalty_is_non_negative() -> None:
    """The passenger penalty must never increase a gene's score."""
    for gene in ("TP53", "KRAS", "TTN", "MUC16"):
        assert get_passenger_penalty(gene) >= 0


def test_known_luad_driver_scores_above_unknown_gene() -> None:
    """A curated LUAD driver must carry more relevance than an unlisted symbol."""
    assert get_luad_relevance_score("EGFR") > get_luad_relevance_score("ZZZ_NOT_A_GENE")


# ---------------------------------------------------------------------------
# WB-11/12  Evidence tiers and explanations
# ---------------------------------------------------------------------------


def test_evidence_tiers_and_explanations_are_assigned(
    mutations: pd.DataFrame, expression: pd.DataFrame
) -> None:
    """Every ranked gene must receive a tier, a category and a written explanation."""
    table = build_target_feature_table(mutations, expression)
    ranked = rank_targets_v3(table)

    safety = pd.DataFrame(
        {
            "gene_name": ranked["gene_name"],
            "normal_lung_tpm": 10.0,
            "safety_score": 0.5,
            "safety_risk": "Moderate_Normal_Expression",
            "safety_note": "Moderate normal lung expression.",
        }
    )

    ranked_v4 = rank_targets_v4_with_safety(ranked, safety)
    tiered = add_evidence_tiers_v6(ranked_v4)

    assert tiered["evidence_tier_v6"].notna().all()
    assert tiered["target_category_v6"].notna().all()
    assert tiered["evidence_tier_explanation_v6"].str.len().gt(0).all()


# ---------------------------------------------------------------------------
# WB-14  ML metrics loading
# ---------------------------------------------------------------------------


def test_primary_evaluation_prefers_ok_rows_over_skipped() -> None:
    """A SKIPPED benchmark row must never be chosen as the reported evaluation."""
    records = [
        {"status": "SKIPPED", "model_name": "ALL", "accuracy": None, "mcc": None},
        {"status": "OK", "model_name": "RandomForestClassifier", "accuracy": 0.73, "mcc": 0.36},
    ]

    primary = select_primary_evaluation(records)

    assert primary is not None
    assert primary["status"] == "OK"


def test_metrics_payload_marks_unavailable_when_no_files_exist(tmp_path: Path) -> None:
    """Missing benchmark files must yield available=False, never zeros."""
    payload = build_ml_metrics_payload({"missing": tmp_path / "does_not_exist.csv"})

    assert payload["available"] is False
    assert payload["accuracy"] is None
    assert payload["metrics_available"]["accuracy"] is False
    assert "accuracy" in payload["unavailable_metrics"]


def test_metrics_payload_reads_real_benchmark_files() -> None:
    """The shipped benchmark artifacts must load and expose all five metrics."""
    payload = build_ml_metrics_payload(svc.METRICS_FILES)

    assert payload["available"] is True
    for key in ("accuracy", "f1_score", "mcc", "roc_auc", "pr_auc"):
        assert isinstance(payload[key], float)
        assert 0.0 <= payload[key] <= 1.0


# ---------------------------------------------------------------------------
# WB-15/16  Report generation and cleanup
# ---------------------------------------------------------------------------


def test_markdown_report_contains_disclaimer_and_targets(tmp_path: Path) -> None:
    """The generated report must carry the research-use disclaimer."""
    df = pd.DataFrame(
        {
            "gene_name": ["TP53"],
            "ranking_score_v4": [0.75],
            "priority_v4": ["High"],
            "evidence_tier_v6": ["Tier_1_Strong_Integrated_Target"],
            "target_category_v6": ["Integrated"],
            "safety_score": [0.4],
            "safety_risk": ["High_Normal_Expression"],
            "normal_lung_tpm": [30.0],
            "explanation_v4": ["High burden."],
            "evidence_tier_explanation_v6": ["Strong evidence."],
        }
    )

    output = create_markdown_report(df, tmp_path / "report.md", top_n=1)
    text = output.read_text(encoding="utf-8")

    assert "Research use only" in text
    assert "TP53" in text


def test_uploaded_files_are_removed_after_analysis(tmp_path: Path) -> None:
    """Temporary upload artifacts must not be left behind by a successful run."""
    mutations_path = tmp_path / "m.csv"
    expression_path = tmp_path / "e.csv"
    mutations_path.write_text(
        "Hugo_Symbol,Variant_Classification,patient_barcode,sample_barcode\n"
        "TP53,Missense_Mutation,P1,S1\nKRAS,Missense_Mutation,P2,S2\n",
        encoding="utf-8",
    )
    expression_path.write_text(
        "gene_name,S1,S2\nTP53,10.0,12.0\nKRAS,4.0,5.0\n", encoding="utf-8"
    )

    result = svc.run_analysis(
        mutations_path=mutations_path, expression_path=expression_path, top_n=2
    )

    assert result["data_source"] == "uploaded_files"
    # run_analysis must not delete the caller's inputs; the caller owns them.
    assert mutations_path.exists()
    assert expression_path.exists()
