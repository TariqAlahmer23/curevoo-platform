"""Tests for the genomic target prioritization FastAPI layer."""

from pathlib import Path

import pandas as pd
import pytest
from fastapi.testclient import TestClient

from app.api.app import app
from app.reports.ml_metrics import (
    build_ml_metrics_payload,
    select_primary_evaluation,
)


@pytest.fixture(scope="module")
def client() -> TestClient:
    with TestClient(app) as test_client:
        yield test_client


def test_health_reports_available_artifacts(client: TestClient) -> None:
    response = client.get("/health")

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "ok"
    assert payload["ok"] is True
    assert payload["cohort_ranking_available"] is True
    assert payload["missing_artifacts"] == []


def test_metrics_are_read_from_persisted_evaluation_files(
    client: TestClient,
) -> None:
    response = client.get("/metrics")

    assert response.status_code == 200
    metrics = response.json()["ml_metrics"]
    assert metrics["available"] is True
    assert metrics["evaluation_strategy"] == "stratified_5_fold_cross_validation"

    # Every reported headline value must match a row in the source CSV.
    source = pd.read_csv(
        Path("outputs/reports/dip_ai_consensus_ncg_civic_metrics.csv")
    )
    matching = source.loc[
        (source["model_name"] == metrics["model_name"])
        & (source["label_mode"] == metrics["label_mode"])
    ]
    assert len(matching) == 1
    for field in ["accuracy", "f1_score", "mcc", "roc_auc", "pr_auc"]:
        assert metrics[field] == pytest.approx(float(matching.iloc[0][field]))


def test_skipped_evaluations_are_never_selected_as_primary() -> None:
    records = [
        {"status": "SKIPPED", "mcc": None, "model_name": "ALL"},
        {"status": "OK", "mcc": 0.2, "model_name": "Weak"},
        {"status": "OK", "mcc": 0.4, "model_name": "Strong"},
    ]

    assert select_primary_evaluation(records)["model_name"] == "Strong"


def test_missing_metrics_files_report_unavailable_instead_of_zero(
    tmp_path: Path,
) -> None:
    payload = build_ml_metrics_payload({"absent": tmp_path / "missing.csv"})

    assert payload["available"] is False
    assert payload["accuracy"] is None
    assert "accuracy" in payload["unavailable_metrics"]
    assert payload["metrics_available"]["accuracy"] is False


def test_analyze_without_uploads_reports_the_reference_cohort(
    client: TestClient,
) -> None:
    response = client.post("/analyze", params={"top_n": 5})

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "success"
    assert payload["data_source"] == "precomputed_cohort"
    assert len(payload["top_targets"]) == 5

    top_target = payload["top_targets"][0]
    assert top_target["rank"] == 1
    assert top_target["gene"] == "TP53"
    assert top_target["priority"] == "High"
    assert top_target["evidence_tier"].startswith("Tier_")
    assert top_target["explanation"]
    assert "NCG" in top_target["external_evidence_sources"]

    assert payload["summary"]["total_targets"] == 17705
    assert payload["report_path"]
    assert "Research-use only" in payload["disclaimer"]


def test_analyze_runs_the_pipeline_over_uploaded_files(
    client: TestClient, tmp_path: Path
) -> None:
    mutations = pd.DataFrame(
        {
            "Hugo_Symbol": ["TP53", "TP53", "KRAS", "BRAF"],
            "patient_barcode": ["P1", "P2", "P1", "P3"],
            "sample_barcode": ["S1", "S2", "S1", "S3"],
            "Variant_Classification": [
                "Missense_Mutation",
                "Nonsense_Mutation",
                "Missense_Mutation",
                "Silent",
            ],
        }
    )
    rna = pd.DataFrame(
        {
            "gene_name": ["TP53", "KRAS", "BRAF"],
            "S1": [40.0, 12.0, 3.0],
            "S2": [35.0, 15.0, 2.0],
        }
    )

    mutations_path = tmp_path / "mutations.csv"
    rna_path = tmp_path / "expression.csv"
    mutations.to_csv(mutations_path, index=False)
    rna.to_csv(rna_path, index=False)

    with mutations_path.open("rb") as mutations_file, rna_path.open("rb") as rna_file:
        response = client.post(
            "/analyze",
            params={"top_n": 3},
            files={
                "mutations_file": ("mutations.csv", mutations_file, "text/csv"),
                "expression_file": ("expression.csv", rna_file, "text/csv"),
            },
        )

    assert response.status_code == 200
    payload = response.json()
    assert payload["data_source"] == "uploaded_files"
    assert payload["inputs"]["mutation_rows"] == 4
    assert payload["summary"]["total_targets"] == 3
    assert {target["gene"] for target in payload["top_targets"]} == {
        "TP53",
        "KRAS",
        "BRAF",
    }


def test_analyze_rejects_a_single_uploaded_file(
    client: TestClient, tmp_path: Path
) -> None:
    mutations_path = tmp_path / "mutations.csv"
    pd.DataFrame({"Hugo_Symbol": ["TP53"]}).to_csv(mutations_path, index=False)

    with mutations_path.open("rb") as mutations_file:
        response = client.post(
            "/analyze",
            files={"mutations_file": ("mutations.csv", mutations_file, "text/csv")},
        )

    assert response.status_code == 400
    assert "RNA expression file" in response.json()["detail"]


def test_stored_run_can_be_replayed_and_reported(client: TestClient) -> None:
    original = client.post("/analyze", params={"top_n": 3}).json()
    run_id = original["run_id"]

    replayed = client.get(f"/results/{run_id}")
    assert replayed.status_code == 200

    # A replayed run must be identical to the original response, including the
    # report location.
    assert replayed.json() == original

    report = client.get(f"/reports/{run_id}")
    assert report.status_code == 200
    assert "# DIP-AI Target Ranking Report" in report.text

    assert client.get("/results/unknownrun123").status_code == 404
    assert client.get("/reports/unknownrun123").status_code == 404
