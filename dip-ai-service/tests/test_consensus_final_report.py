"""Tests for the final DIP-AI scientific report builder."""

from pathlib import Path

import pandas as pd

from app.reports.consensus_final_report import (
    DISCLAIMER,
    build_final_report,
    extract_key_results,
    load_csv_if_exists,
    load_text_file,
)


def test_report_load_helpers(tmp_path: Path) -> None:
    text_path = tmp_path / "example.txt"
    text_path.write_text("scientific result", encoding="utf-8")
    csv_path = tmp_path / "example.csv"
    pd.DataFrame({"value": [1, 2]}).to_csv(csv_path, index=False)

    assert load_text_file(text_path) == "scientific result"
    assert load_csv_if_exists(csv_path)["value"].tolist() == [1, 2]
    assert load_csv_if_exists(tmp_path / "missing.csv").empty


def test_extract_key_results_matches_final_artifacts() -> None:
    results = extract_key_results()

    assert results["ranking"]["total_targets"] == 17705
    assert results["ranking"]["priority_counts"] == {
        "High": 2,
        "Medium": 722,
        "Low": 16981,
    }
    assert results["ranking"]["tier_1_targets"] == ["TP53", "KRAS"]
    assert results["quality_audit"]["status"] == "PASS"
    assert results["quality_audit"]["total_issues"] == 0
    assert results["consensus"]["coverage"]["high_confidence_ranked_count"] == 504
    assert results["consensus"]["high_confidence_delta"]["roc_auc"] > 0


def test_build_final_report_creates_markdown_and_text(
    tmp_path: Path,
) -> None:
    markdown_path = build_final_report(tmp_path / "final.md")
    text_path = build_final_report(tmp_path / "final.txt")
    markdown = markdown_path.read_text(encoding="utf-8")
    plain_text = text_path.read_text(encoding="utf-8")

    assert DISCLAIMER in markdown
    assert "# 1. DIP-AI:" in markdown
    for section_number in range(2, 18):
        assert f"## {section_number}." in markdown
    assert "TP53" in markdown
    assert "KRAS" in markdown
    assert "RET" in markdown
    assert "ALK" in markdown
    assert "ROC-AUC" in markdown
    assert "Quality Audit" in markdown
    assert "11. Leakage-Minimized NCG Benchmark" in markdown
    assert "13. CIViC + NCG Consensus Benchmark" in markdown

    assert "# 1." not in plain_text
    assert "**" not in plain_text
    assert "1. DIP-AI:" in plain_text
    assert "17. Final Conclusion" in plain_text
