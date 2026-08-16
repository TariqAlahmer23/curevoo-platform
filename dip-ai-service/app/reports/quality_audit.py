"""Quality audit checks for DIP-AI final research outputs."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pandas as pd

from app.core.config import OUTPUT_DIR, PROCESSED_DIR


REPORTS_DIR = OUTPUT_DIR / "reports"

REQUIRED_INPUT_PATHS = {
    "target_features_v2": PROCESSED_DIR / "target_features_v2.csv",
    "target_ranking_v3": PROCESSED_DIR / "target_ranking_v3.csv",
    "target_ranking_v4": PROCESSED_DIR / "target_ranking_v4.csv",
    "target_ranking_v6_evidence_tiers": (
        PROCESSED_DIR / "target_ranking_v6_evidence_tiers.csv"
    ),
    "dashboard_payload": REPORTS_DIR / "dip_ai_dashboard_payload.json",
    "target_ranking_report": REPORTS_DIR / "dip_ai_target_ranking_report.md",
}

FEATURES_REQUIRED_COLUMNS = [
    "gene_name",
    "mutation_frequency_score",
    "expression_score",
    "protein_impact_score",
    "candidate_score_v2_features",
]

RANKING_V3_REQUIRED_COLUMNS = [
    "gene_name",
    "mutation_frequency_score",
    "expression_score",
    "protein_impact_score",
    "luad_relevance_score",
    "passenger_penalty",
    "targetability_score",
    "dormancy_evidence_score",
    "ranking_score_v3",
    "priority_v3",
]

RANKING_V4_REQUIRED_COLUMNS = [
    "gene_name",
    "ranking_score_v3",
    "ranking_score_v4",
    "priority_v4",
    "normal_lung_tpm",
    "safety_score",
    "safety_risk",
    "safety_penalty",
]

FINAL_RANKING_REQUIRED_COLUMNS = [
    "gene_name",
    "ranking_score_v3",
    "ranking_score_v4",
    "priority_v4",
    "evidence_tier_v6",
    "target_category_v6",
    "safety_score",
    "safety_penalty",
    "passenger_penalty",
    "targetability_score",
    "dormancy_evidence_score",
    "luad_relevance_score",
]

SCORE_RANGE_COLUMNS = [
    "ranking_score_v3",
    "ranking_score_v4",
    "safety_score",
    "mutation_frequency_score",
    "expression_score",
    "protein_impact_score",
    "luad_relevance_score",
    "targetability_score",
    "dormancy_evidence_score",
    "passenger_penalty",
]

PASSENGER_LIKE_GENES = {"TTN", "MUC16", "RYR2", "CSMD3", "LRP1B"}
TIER_1 = "Tier_1_Strong_Integrated_Target"
TIER_2_SAFETY_SUPPORTED = "Tier_2_Actionable_Safety_Supported"
TIER_2_SAFETY_CAUTION = "Tier_2_Actionable_With_Safety_Caution"
TIER_3_DORMANCY = "Tier_3_Dormancy_Exploratory_Target"
TIER_4_PASSENGER = "Tier_4_Passenger_Background_Like"

FLOAT_TOLERANCE = 1e-9
PENALTY_TOLERANCE = 1e-6


def check_required_files(paths: dict) -> list[str]:
    """Verify all required files exist."""
    issues = []
    for name, path_value in paths.items():
        path = Path(path_value)
        if not path.exists():
            issues.append(f"Missing required file [{name}]: {path}")

    return issues


def check_required_columns(
    df: pd.DataFrame, required_columns: list[str], table_name: str
) -> list[str]:
    """Verify a dataframe contains all required columns."""
    missing_columns = [column for column in required_columns if column not in df.columns]
    if not missing_columns:
        return []

    return [
        f"{table_name} is missing required columns: {', '.join(missing_columns)}"
    ]


def check_no_duplicate_genes(df: pd.DataFrame, table_name: str) -> list[str]:
    """Verify gene_name is unique in a dataframe."""
    if "gene_name" not in df.columns:
        return [f"{table_name} cannot be checked for duplicate genes: missing gene_name"]

    duplicate_mask = df["gene_name"].duplicated(keep=False)
    if not duplicate_mask.any():
        return []

    duplicate_genes = sorted(df.loc[duplicate_mask, "gene_name"].astype(str).unique())
    return [
        f"{table_name} contains duplicate gene_name values: "
        f"{_format_examples(duplicate_genes)}"
    ]


def check_score_ranges(df: pd.DataFrame) -> list[str]:
    """Verify score-like columns are within the inclusive 0 to 1 range when present."""
    issues = []
    for column in SCORE_RANGE_COLUMNS:
        if column not in df.columns:
            continue

        numeric_values = pd.to_numeric(df[column], errors="coerce")
        invalid_mask = numeric_values.isna() | (numeric_values < 0) | (numeric_values > 1)
        if not invalid_mask.any():
            continue

        gene_examples = _row_gene_examples(df.loc[invalid_mask])
        valid_values = numeric_values.dropna()
        if valid_values.empty:
            range_text = "all values are non-numeric or missing"
        else:
            range_text = (
                f"observed numeric range {valid_values.min():.6g} "
                f"to {valid_values.max():.6g}"
            )
        issues.append(
            f"{column} has {int(invalid_mask.sum())} values outside 0..1 "
            f"or missing/non-numeric values ({range_text}); examples: {gene_examples}"
        )

    return issues


def check_v4_safety_logic(df: pd.DataFrame) -> list[str]:
    """Verify V4 safety penalty and score adjustment logic."""
    issues = []
    required_columns = [
        "gene_name",
        "ranking_score_v3",
        "ranking_score_v4",
        "safety_score",
        "safety_penalty",
    ]
    missing_issues = check_required_columns(df, required_columns, "V4 safety logic input")
    if missing_issues:
        return missing_issues

    ranking_score_v3 = pd.to_numeric(df["ranking_score_v3"], errors="coerce")
    ranking_score_v4 = pd.to_numeric(df["ranking_score_v4"], errors="coerce")
    safety_score = pd.to_numeric(df["safety_score"], errors="coerce")
    safety_penalty = pd.to_numeric(df["safety_penalty"], errors="coerce")

    score_increase_mask = ranking_score_v4 > ranking_score_v3 + FLOAT_TOLERANCE
    if score_increase_mask.any():
        issues.append(
            "ranking_score_v4 is greater than ranking_score_v3 for "
            f"{int(score_increase_mask.sum())} genes; examples: "
            f"{_row_gene_examples(df.loc[score_increase_mask])}"
        )

    penalty_range_mask = (
        safety_penalty.isna()
        | (safety_penalty < -FLOAT_TOLERANCE)
        | (safety_penalty > 0.20 + FLOAT_TOLERANCE)
    )
    if penalty_range_mask.any():
        issues.append(
            "safety_penalty is outside 0..0.20 or missing for "
            f"{int(penalty_range_mask.sum())} genes; examples: "
            f"{_row_gene_examples(df.loc[penalty_range_mask])}"
        )

    expected_penalties = {
        1.00: 0.00,
        0.45: 0.11,
        0.20: 0.16,
    }
    for score, expected_penalty in expected_penalties.items():
        score_mask = safety_score.sub(score).abs() <= PENALTY_TOLERANCE
        mismatch_mask = score_mask & (
            safety_penalty.sub(expected_penalty).abs() > PENALTY_TOLERANCE
        )
        if mismatch_mask.any():
            issues.append(
                f"safety_score {score:.2f} should map to safety_penalty "
                f"{expected_penalty:.2f}; mismatches: {int(mismatch_mask.sum())}; "
                f"examples: {_row_gene_examples(df.loc[mismatch_mask])}"
            )

    return issues


def check_priority_logic(df: pd.DataFrame) -> list[str]:
    """Verify priority_v4 labels match ranking_score_v4 thresholds."""
    required_columns = ["gene_name", "ranking_score_v4", "priority_v4"]
    missing_issues = check_required_columns(df, required_columns, "priority logic input")
    if missing_issues:
        return missing_issues

    scores = pd.to_numeric(df["ranking_score_v4"], errors="coerce")
    expected_priority = pd.Series("Low", index=df.index)
    expected_priority.loc[scores >= 0.70] = "High"
    expected_priority.loc[(scores >= 0.40) & (scores < 0.70)] = "Medium"

    mismatch_mask = scores.isna() | (df["priority_v4"].astype(str) != expected_priority)
    if not mismatch_mask.any():
        return []

    examples = _priority_examples(df.loc[mismatch_mask], expected_priority.loc[mismatch_mask])
    return [
        f"priority_v4 does not match ranking_score_v4 thresholds for "
        f"{int(mismatch_mask.sum())} genes; examples: {examples}"
    ]


def check_evidence_tier_logic(df: pd.DataFrame) -> list[str]:
    """Verify V6 evidence tiers obey required biological and technical rules."""
    issues = []
    required_columns = [
        "gene_name",
        "ranking_score_v4",
        "evidence_tier_v6",
        "passenger_penalty",
        "targetability_score",
        "safety_score",
        "dormancy_evidence_score",
    ]
    missing_issues = check_required_columns(
        df, required_columns, "evidence tier logic input"
    )
    if missing_issues:
        return missing_issues

    passenger_penalty = pd.to_numeric(df["passenger_penalty"], errors="coerce")
    ranking_score_v4 = pd.to_numeric(df["ranking_score_v4"], errors="coerce")
    targetability_score = pd.to_numeric(df["targetability_score"], errors="coerce")
    safety_score = pd.to_numeric(df["safety_score"], errors="coerce")
    dormancy_evidence_score = pd.to_numeric(
        df["dormancy_evidence_score"], errors="coerce"
    )
    evidence_tier = df["evidence_tier_v6"].astype(str)

    passenger_mask = passenger_penalty > FLOAT_TOLERANCE
    passenger_mismatch = passenger_mask & (evidence_tier != TIER_4_PASSENGER)
    if passenger_mismatch.any():
        issues.append(
            "Genes with passenger_penalty > 0 must be "
            f"{TIER_4_PASSENGER}; mismatches: {int(passenger_mismatch.sum())}; "
            f"examples: {_row_gene_examples(df.loc[passenger_mismatch])}"
        )

    tier_1_mismatch = (evidence_tier == TIER_1) & (
        ranking_score_v4.isna() | (ranking_score_v4 < 0.70)
    )
    if tier_1_mismatch.any():
        issues.append(
            f"{TIER_1} requires ranking_score_v4 >= 0.70; mismatches: "
            f"{int(tier_1_mismatch.sum())}; examples: "
            f"{_row_gene_examples(df.loc[tier_1_mismatch])}"
        )

    tier_2_supported_mismatch = (evidence_tier == TIER_2_SAFETY_SUPPORTED) & (
        targetability_score.isna()
        | safety_score.isna()
        | (targetability_score < 1.0)
        | (safety_score < 0.75)
    )
    if tier_2_supported_mismatch.any():
        issues.append(
            f"{TIER_2_SAFETY_SUPPORTED} requires targetability_score >= 1.0 "
            "and safety_score >= 0.75; mismatches: "
            f"{int(tier_2_supported_mismatch.sum())}; examples: "
            f"{_row_gene_examples(df.loc[tier_2_supported_mismatch])}"
        )

    tier_2_caution_mismatch = (evidence_tier == TIER_2_SAFETY_CAUTION) & (
        targetability_score.isna()
        | safety_score.isna()
        | (targetability_score < 1.0)
        | (safety_score >= 0.75)
    )
    if tier_2_caution_mismatch.any():
        issues.append(
            f"{TIER_2_SAFETY_CAUTION} requires targetability_score >= 1.0 "
            "and safety_score < 0.75; mismatches: "
            f"{int(tier_2_caution_mismatch.sum())}; examples: "
            f"{_row_gene_examples(df.loc[tier_2_caution_mismatch])}"
        )

    tier_3_dormancy_mismatch = (evidence_tier == TIER_3_DORMANCY) & (
        dormancy_evidence_score.isna() | (dormancy_evidence_score < 1.0)
    )
    if tier_3_dormancy_mismatch.any():
        issues.append(
            f"{TIER_3_DORMANCY} requires dormancy_evidence_score >= 1.0; "
            f"mismatches: {int(tier_3_dormancy_mismatch.sum())}; examples: "
            f"{_row_gene_examples(df.loc[tier_3_dormancy_mismatch])}"
        )

    return issues


def check_biological_sanity(df: pd.DataFrame) -> list[str]:
    """Verify sentinel LUAD/actionability/passenger biological expectations."""
    issues = []
    required_columns = [
        "gene_name",
        "ranking_score_v4",
        "priority_v4",
        "evidence_tier_v6",
        "target_category_v6",
        "safety_score",
        "targetability_score",
        "passenger_penalty",
    ]
    missing_issues = check_required_columns(
        df, required_columns, "biological sanity input"
    )
    if missing_issues:
        return missing_issues

    by_gene = _index_by_gene(df)

    for gene in ["TP53", "KRAS"]:
        row = by_gene.get(gene)
        if row is None:
            issues.append(f"Biological sanity check failed: {gene} is missing")
            continue
        if not _is_high_priority_or_tier_1(row):
            issues.append(
                f"Biological sanity check failed: {gene} should be High priority "
                f"or Tier 1, observed priority_v4={row.get('priority_v4')} and "
                f"evidence_tier_v6={row.get('evidence_tier_v6')}"
            )

    egfr = by_gene.get("EGFR")
    if egfr is None:
        issues.append("Biological sanity check failed: EGFR is missing")
    elif not _is_clinically_actionable(egfr):
        issues.append(
            "Biological sanity check failed: EGFR should be clinically actionable, "
            f"observed targetability_score={egfr.get('targetability_score')}, "
            f"target_category_v6={egfr.get('target_category_v6')}, "
            f"evidence_tier_v6={egfr.get('evidence_tier_v6')}"
        )

    for gene in ["ALK", "RET"]:
        row = by_gene.get(gene)
        if row is None:
            issues.append(f"Biological sanity check failed: {gene} is missing")
            continue
        if not _is_clinically_actionable(row):
            issues.append(
                f"Biological sanity check failed: {gene} should be clinically "
                f"actionable, observed targetability_score={row.get('targetability_score')}"
            )

        safety_score = _to_float(row.get("safety_score"))
        if safety_score is not None and safety_score >= 0.75 and not _is_safety_supported(row):
            issues.append(
                f"Biological sanity check failed: {gene} has safety_score "
                f"{safety_score:.3g} and should be safety supported, observed "
                f"target_category_v6={row.get('target_category_v6')} and "
                f"evidence_tier_v6={row.get('evidence_tier_v6')}"
            )

    for gene in sorted(PASSENGER_LIKE_GENES):
        row = by_gene.get(gene)
        if row is None:
            continue
        if _is_high_priority_or_tier_1(row):
            issues.append(
                f"Biological sanity check failed: passenger-like gene {gene} "
                "should not be High priority or Tier 1, observed "
                f"priority_v4={row.get('priority_v4')} and "
                f"evidence_tier_v6={row.get('evidence_tier_v6')}"
            )

    ranking_scores = pd.to_numeric(df["ranking_score_v4"], errors="coerce")
    top_10 = df.assign(_ranking_score_v4=ranking_scores).sort_values(
        "_ranking_score_v4", ascending=False
    ).head(10)
    top_10_passenger_mask = (
        top_10["gene_name"].astype(str).isin(PASSENGER_LIKE_GENES)
        | (pd.to_numeric(top_10["passenger_penalty"], errors="coerce") > FLOAT_TOLERANCE)
        | (top_10["evidence_tier_v6"].astype(str) == TIER_4_PASSENGER)
    )
    if top_10_passenger_mask.any():
        issues.append(
            "Passenger-like genes should not appear in the top 10 by ranking_score_v4; "
            f"observed: {_row_gene_examples(top_10.loc[top_10_passenger_mask])}"
        )

    return issues


def check_dashboard_consistency(
    df: pd.DataFrame, dashboard_payload: dict
) -> list[str]:
    """Verify dashboard aggregate counts and top target match final ranking."""
    issues = []
    required_columns = [
        "gene_name",
        "ranking_score_v4",
        "priority_v4",
        "evidence_tier_v6",
        "target_category_v6",
    ]
    missing_issues = check_required_columns(
        df, required_columns, "dashboard consistency input"
    )
    if missing_issues:
        return missing_issues

    if not isinstance(dashboard_payload, dict):
        return ["Dashboard payload is not a JSON object"]

    total_targets = dashboard_payload.get("total_targets")
    if total_targets != len(df):
        issues.append(
            f"Dashboard total_targets mismatch: payload={total_targets}, "
            f"final_ranking_rows={len(df)}"
        )

    priority_counts = df["priority_v4"].value_counts()
    priority_payload_keys = {
        "High": "high_priority_count",
        "Medium": "medium_priority_count",
        "Low": "low_priority_count",
    }
    for priority, payload_key in priority_payload_keys.items():
        expected_count = int(priority_counts.get(priority, 0))
        observed_count = dashboard_payload.get(payload_key)
        if observed_count != expected_count:
            issues.append(
                f"Dashboard {payload_key} mismatch: payload={observed_count}, "
                f"final_ranking={expected_count}"
            )

    expected_tier_counts = _value_counts_as_dict(df["evidence_tier_v6"])
    observed_tier_counts = dashboard_payload.get("evidence_tier_counts")
    issues.extend(
        _compare_count_dicts(
            observed_tier_counts,
            expected_tier_counts,
            "Dashboard evidence_tier_counts",
        )
    )

    expected_category_counts = _value_counts_as_dict(df["target_category_v6"])
    observed_category_counts = dashboard_payload.get("target_category_counts")
    issues.extend(
        _compare_count_dicts(
            observed_category_counts,
            expected_category_counts,
            "Dashboard target_category_counts",
        )
    )

    top_targets = dashboard_payload.get("top_targets")
    if not isinstance(top_targets, list) or not top_targets:
        issues.append("Dashboard top_targets is missing or empty")
    elif len(df) > 0:
        ranking_scores = pd.to_numeric(df["ranking_score_v4"], errors="coerce")
        final_top_gene = (
            df.assign(_ranking_score_v4=ranking_scores)
            .sort_values("_ranking_score_v4", ascending=False)
            .iloc[0]["gene_name"]
        )
        dashboard_top_gene = top_targets[0].get("gene_name")
        if dashboard_top_gene != final_top_gene:
            issues.append(
                "Dashboard top target #1 mismatch: "
                f"payload={dashboard_top_gene}, final_ranking={final_top_gene}"
            )

    return issues


def run_quality_audit() -> dict:
    """Run all quality audit checks and return a structured audit result."""
    issues = []
    check_issue_counts: dict[str, int] = {}
    dataframes: dict[str, pd.DataFrame] = {}
    dashboard_payload: dict[str, Any] | None = None

    def add_check_result(check_name: str, check_issues: list[str]) -> None:
        check_issue_counts[check_name] = len(check_issues)
        issues.extend(check_issues)

    add_check_result(
        "required_files", check_required_files(REQUIRED_INPUT_PATHS)
    )

    dataframe_inputs = {
        "target_features_v2": REQUIRED_INPUT_PATHS["target_features_v2"],
        "target_ranking_v3": REQUIRED_INPUT_PATHS["target_ranking_v3"],
        "target_ranking_v4": REQUIRED_INPUT_PATHS["target_ranking_v4"],
        "target_ranking_v6_evidence_tiers": REQUIRED_INPUT_PATHS[
            "target_ranking_v6_evidence_tiers"
        ],
    }
    for table_name, path in dataframe_inputs.items():
        if not Path(path).exists():
            continue
        try:
            dataframes[table_name] = pd.read_csv(path)
        except Exception as exc:  # pragma: no cover - defensive read barrier
            add_check_result(
                f"load_{table_name}",
                [f"Failed to load {table_name} from {path}: {exc}"],
            )

    dashboard_path = REQUIRED_INPUT_PATHS["dashboard_payload"]
    if Path(dashboard_path).exists():
        try:
            dashboard_payload = json.loads(Path(dashboard_path).read_text(encoding="utf-8"))
        except Exception as exc:  # pragma: no cover - defensive read barrier
            add_check_result(
                "load_dashboard_payload",
                [f"Failed to load dashboard payload from {dashboard_path}: {exc}"],
            )

    if "target_features_v2" in dataframes:
        add_check_result(
            "target_features_v2_required_columns",
            check_required_columns(
                dataframes["target_features_v2"],
                FEATURES_REQUIRED_COLUMNS,
                "target_features_v2",
            ),
        )

    if "target_ranking_v3" in dataframes:
        add_check_result(
            "target_ranking_v3_required_columns",
            check_required_columns(
                dataframes["target_ranking_v3"],
                RANKING_V3_REQUIRED_COLUMNS,
                "target_ranking_v3",
            ),
        )

    if "target_ranking_v4" in dataframes:
        add_check_result(
            "target_ranking_v4_required_columns",
            check_required_columns(
                dataframes["target_ranking_v4"],
                RANKING_V4_REQUIRED_COLUMNS,
                "target_ranking_v4",
            ),
        )

    final_df = dataframes.get("target_ranking_v6_evidence_tiers")
    if final_df is not None:
        add_check_result(
            "final_ranking_required_columns",
            check_required_columns(
                final_df,
                FINAL_RANKING_REQUIRED_COLUMNS,
                "target_ranking_v6_evidence_tiers",
            ),
        )
        add_check_result(
            "final_ranking_duplicate_genes",
            check_no_duplicate_genes(final_df, "target_ranking_v6_evidence_tiers"),
        )
        add_check_result("score_ranges", check_score_ranges(final_df))
        add_check_result("v4_safety_logic", check_v4_safety_logic(final_df))
        add_check_result("priority_logic", check_priority_logic(final_df))
        add_check_result("evidence_tier_logic", check_evidence_tier_logic(final_df))
        add_check_result("biological_sanity", check_biological_sanity(final_df))

        if dashboard_payload is not None:
            add_check_result(
                "dashboard_consistency",
                check_dashboard_consistency(final_df, dashboard_payload),
            )

    summary = _build_summary(dataframes, dashboard_payload, check_issue_counts)

    return {
        "status": "PASS" if not issues else "FAIL",
        "total_issues": len(issues),
        "issues": issues,
        "summary": summary,
    }


def format_quality_audit_report(audit_result: dict) -> str:
    """Create a readable text report from a quality audit result."""
    summary = audit_result.get("summary", {})
    lines = [
        "DIP-AI Quality Audit Report",
        "===========================",
        f"Status: {audit_result.get('status')}",
        f"Total issues: {audit_result.get('total_issues')}",
        "",
        "Summary",
        "-------",
        f"Required files checked: {summary.get('required_files_checked')}",
        f"Tables loaded: {', '.join(summary.get('tables_loaded', []))}",
        f"Final ranking rows: {summary.get('final_ranking_rows')}",
        f"Dashboard total_targets: {summary.get('dashboard_total_targets')}",
        "",
        "Final priority counts",
        "---------------------",
    ]

    for priority, count in summary.get("priority_counts", {}).items():
        lines.append(f"{priority}: {count}")

    lines.extend(["", "Evidence tier counts", "--------------------"])
    for tier, count in summary.get("evidence_tier_counts", {}).items():
        lines.append(f"{tier}: {count}")

    lines.extend(["", "Target category counts", "----------------------"])
    for category, count in summary.get("target_category_counts", {}).items():
        lines.append(f"{category}: {count}")

    lines.extend(["", "Check issue counts", "------------------"])
    for check_name, count in summary.get("check_issue_counts", {}).items():
        lines.append(f"{check_name}: {count}")

    lines.extend(["", "Issues", "------"])
    issues = audit_result.get("issues", [])
    if issues:
        lines.extend(f"{index}. {issue}" for index, issue in enumerate(issues, start=1))
    else:
        lines.append("No issues detected.")

    return "\n".join(lines) + "\n"


def _build_summary(
    dataframes: dict[str, pd.DataFrame],
    dashboard_payload: dict[str, Any] | None,
    check_issue_counts: dict[str, int],
) -> dict[str, Any]:
    final_df = dataframes.get("target_ranking_v6_evidence_tiers")
    summary: dict[str, Any] = {
        "required_files_checked": len(REQUIRED_INPUT_PATHS),
        "tables_loaded": sorted(dataframes.keys()),
        "check_issue_counts": check_issue_counts,
        "final_ranking_rows": None,
        "dashboard_total_targets": None,
        "priority_counts": {},
        "evidence_tier_counts": {},
        "target_category_counts": {},
        "top_target": None,
    }

    if final_df is not None:
        summary["final_ranking_rows"] = int(len(final_df))
        if "priority_v4" in final_df.columns:
            summary["priority_counts"] = _value_counts_as_dict(final_df["priority_v4"])
        if "evidence_tier_v6" in final_df.columns:
            summary["evidence_tier_counts"] = _value_counts_as_dict(
                final_df["evidence_tier_v6"]
            )
        if "target_category_v6" in final_df.columns:
            summary["target_category_counts"] = _value_counts_as_dict(
                final_df["target_category_v6"]
            )
        if {"gene_name", "ranking_score_v4"}.issubset(final_df.columns) and len(final_df) > 0:
            ranking_scores = pd.to_numeric(final_df["ranking_score_v4"], errors="coerce")
            top_row = (
                final_df.assign(_ranking_score_v4=ranking_scores)
                .sort_values("_ranking_score_v4", ascending=False)
                .iloc[0]
            )
            summary["top_target"] = {
                "gene_name": str(top_row["gene_name"]),
                "ranking_score_v4": float(top_row["_ranking_score_v4"]),
            }

    if isinstance(dashboard_payload, dict):
        summary["dashboard_total_targets"] = dashboard_payload.get("total_targets")

    return summary


def _compare_count_dicts(
    observed_counts: Any, expected_counts: dict[str, int], label: str
) -> list[str]:
    if not isinstance(observed_counts, dict):
        return [f"{label} is missing or is not a JSON object"]

    observed_normalized = {}
    issues = []
    for key, value in observed_counts.items():
        try:
            observed_normalized[str(key)] = int(value)
        except (TypeError, ValueError):
            issues.append(f"{label} has non-integer count for {key}: {value}")

    all_keys = sorted(set(expected_counts) | set(observed_normalized))
    for key in all_keys:
        observed_count = observed_normalized.get(key, 0)
        expected_count = expected_counts.get(key, 0)
        if observed_count != expected_count:
            issues.append(
                f"{label} mismatch for {key}: payload={observed_count}, "
                f"final_ranking={expected_count}"
            )

    return issues


def _value_counts_as_dict(series: pd.Series) -> dict[str, int]:
    return {
        str(key): int(value)
        for key, value in series.value_counts(dropna=False).items()
    }


def _index_by_gene(df: pd.DataFrame) -> dict[str, pd.Series]:
    indexed: dict[str, pd.Series] = {}
    for _, row in df.iterrows():
        gene_name = str(row.get("gene_name", "")).strip()
        if gene_name and gene_name not in indexed:
            indexed[gene_name] = row

    return indexed


def _is_high_priority_or_tier_1(row: pd.Series) -> bool:
    return str(row.get("priority_v4")) == "High" or str(row.get("evidence_tier_v6")) == TIER_1


def _is_clinically_actionable(row: pd.Series) -> bool:
    targetability_score = _to_float(row.get("targetability_score"))
    category = str(row.get("target_category_v6", ""))
    evidence_tier = str(row.get("evidence_tier_v6", ""))
    return (
        (targetability_score is not None and targetability_score >= 1.0)
        or "Clinically Actionable" in category
        or "Actionable" in evidence_tier
    )


def _is_safety_supported(row: pd.Series) -> bool:
    category = str(row.get("target_category_v6", ""))
    evidence_tier = str(row.get("evidence_tier_v6", ""))
    return "Safety Supported" in category or evidence_tier == TIER_2_SAFETY_SUPPORTED


def _to_float(value: Any) -> float | None:
    try:
        converted = float(value)
    except (TypeError, ValueError):
        return None
    if pd.isna(converted):
        return None

    return converted


def _row_gene_examples(df: pd.DataFrame, limit: int = 5) -> str:
    if "gene_name" not in df.columns:
        return "unavailable"

    return _format_examples(df["gene_name"].astype(str).head(limit).tolist())


def _priority_examples(df: pd.DataFrame, expected_priority: pd.Series, limit: int = 5) -> str:
    examples = []
    for index, row in df.head(limit).iterrows():
        examples.append(
            f"{row.get('gene_name')} observed={row.get('priority_v4')} "
            f"expected={expected_priority.loc[index]}"
        )

    return _format_examples(examples)


def _format_examples(values: list[str], limit: int = 5) -> str:
    shown = [str(value) for value in values[:limit]]
    if len(values) > limit:
        shown.append(f"... plus {len(values) - limit} more")

    return ", ".join(shown) if shown else "none"
