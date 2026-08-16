"""Genomic target prioritization workflow behind the FastAPI layer.

This module only orchestrates: every scoring, safety, tiering, explanation, and
reporting rule is reused from the existing pipeline packages so the API and the
batch scripts in ``scripts/`` stay behaviourally identical.
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from uuid import uuid4
import json
import threading

import pandas as pd

from app.core.config import (
    CONSENSUS_LABELS_FILE,
    CONSENSUS_METRICS_FILE,
    LEAKAGE_MINIMIZED_METRICS_FILE,
    RANKING_V6_FILE,
    REPORTS_DIR,
    RUNS_DIR,
    SAFETY_FEATURES_FILE,
)
from app.features.target_features import build_target_feature_table
from app.models.evidence_tiering import add_evidence_tiers_v6
from app.models.explainability import (
    add_ranking_explanations_v3,
    add_ranking_explanations_v4,
)
from app.models.ranking_engine import rank_targets_v3, rank_targets_v4_with_safety
from app.reports.final_outputs import (
    create_category_summary,
    create_markdown_report,
    create_tier_summary,
    create_top_targets_table,
    load_v6_results,
)
from app.reports.ml_metrics import build_ml_metrics_payload


METRICS_FILES = {
    "ncg_civic_consensus": CONSENSUS_METRICS_FILE,
    "ncg_leakage_minimized": LEAKAGE_MINIMIZED_METRICS_FILE,
}

DEFAULT_TOP_N = 20
MAX_TOP_N = 100

_CACHE_LOCK = threading.Lock()
_TABLE_CACHE: dict[Path, tuple[float, pd.DataFrame]] = {}


class AnalysisInputError(ValueError):
    """Raised when supplied analysis inputs cannot be used."""


class PipelineDataError(RuntimeError):
    """Raised when a required pipeline artifact is missing or unusable."""


def _read_cached_csv(path: Path) -> pd.DataFrame:
    """
    Read a pipeline CSV, reusing the parsed table until the file changes.

    Args:
        path: Path to a pipeline CSV artifact.

    Returns:
        A copy of the cached dataframe.
    """
    if not path.exists():
        raise PipelineDataError(f"Required pipeline file not found: {path.name}")

    modified_at = path.stat().st_mtime

    with _CACHE_LOCK:
        cached = _TABLE_CACHE.get(path)
        if cached is not None and cached[0] == modified_at:
            return cached[1].copy()

    table = pd.read_csv(path, low_memory=False)

    with _CACHE_LOCK:
        _TABLE_CACHE[path] = (modified_at, table)

    return table.copy()


def _optional_float(value: Any) -> float | None:
    """Return a finite float, or ``None`` for missing values."""
    number = pd.to_numeric(value, errors="coerce")
    if pd.isna(number):
        return None

    return float(number)


def _text(value: Any, default: str = "") -> str:
    """Return trimmed text, falling back to ``default`` for missing values."""
    if value is None or (not isinstance(value, str) and pd.isna(value)):
        return default

    return str(value).strip() or default


def _load_external_evidence() -> pd.DataFrame:
    """
    Load NCG/CIViC consensus evidence, or an empty table when unavailable.

    Returns:
        Dataframe with ``gene_name``, ``external_sources``, and
        ``consensus_confidence`` columns.
    """
    if not CONSENSUS_LABELS_FILE.exists():
        return pd.DataFrame(
            columns=["gene_name", "external_sources", "consensus_confidence"]
        )

    evidence = _read_cached_csv(CONSENSUS_LABELS_FILE)
    columns = [
        column
        for column in ["gene_name", "external_sources", "consensus_confidence"]
        if column in evidence.columns
    ]

    return evidence.loc[:, columns]


def _match_external_evidence(ranked: pd.DataFrame) -> pd.DataFrame:
    """
    Attach external NCG/CIViC evidence to ranked targets by gene symbol.

    Args:
        ranked: Ranked target dataframe carrying a ``gene_name`` column.

    Returns:
        Copy of ``ranked`` with ``external_sources`` and
        ``consensus_confidence`` columns added.
    """
    evidence = _load_external_evidence()
    matched = ranked.copy()

    if evidence.empty or "gene_name" not in evidence.columns:
        matched["external_sources"] = ""
        matched["consensus_confidence"] = pd.NA
        return matched

    normalized_evidence = evidence.copy()
    normalized_evidence["gene_key"] = (
        normalized_evidence["gene_name"].astype("string").str.strip().str.upper()
    )
    normalized_evidence = normalized_evidence.drop(columns=["gene_name"]).drop_duplicates(
        subset=["gene_key"]
    )

    matched["gene_key"] = matched["gene_name"].astype("string").str.strip().str.upper()
    matched = matched.merge(normalized_evidence, on="gene_key", how="left")

    return matched.drop(columns=["gene_key"])


def _restore_context_columns(
    top_targets: pd.DataFrame, matched: pd.DataFrame
) -> pd.DataFrame:
    """
    Re-attach context columns dropped by the presentation top-targets table.

    ``create_top_targets_table`` intentionally narrows to presentation columns,
    so the safety note and external evidence are merged back by gene symbol.

    Args:
        top_targets: Presentation-ready top-targets table.
        matched: Full ranking table after external evidence matching.

    Returns:
        The top-targets table with context columns restored.
    """
    context_columns = [
        column
        for column in ["safety_note", "external_sources", "consensus_confidence"]
        if column in matched.columns
    ]
    if not context_columns:
        return top_targets

    context = matched.loc[:, ["gene_name", *context_columns]].drop_duplicates(
        subset=["gene_name"]
    )

    return top_targets.merge(context, on="gene_name", how="left")


def _build_ranked_targets(top_targets: pd.DataFrame) -> list[dict[str, Any]]:
    """
    Convert the presentation top-targets table into API target records.

    Args:
        top_targets: Table produced by ``create_top_targets_table`` after
            external evidence matching.

    Returns:
        Ranked target records ready for the response schema.
    """
    records: list[dict[str, Any]] = []

    for _, row in top_targets.iterrows():
        sources = _text(row.get("external_sources"))
        records.append(
            {
                "rank": int(row["rank"]),
                "gene": _text(row.get("gene_name"), "Unknown"),
                "ranking_score": float(_optional_float(row.get("ranking_score_v4")) or 0.0),
                "priority": _text(row.get("priority_v4"), "Low"),
                "evidence_tier": _text(row.get("evidence_tier_v6"), "Unknown"),
                "target_category": _text(row.get("target_category_v6"), "Unknown"),
                "safety_risk": _text(row.get("safety_risk"), "Unknown"),
                "safety_score": _optional_float(row.get("safety_score")),
                "safety_note": _text(row.get("safety_note")) or None,
                "normal_lung_tpm": _optional_float(row.get("normal_lung_tpm")),
                "explanation": _text(row.get("explanation_v4")),
                "evidence_tier_explanation": _text(
                    row.get("evidence_tier_explanation_v6")
                )
                or None,
                "external_evidence_sources": [
                    source for source in sources.split(";") if source
                ],
                "external_evidence_confidence": _text(row.get("consensus_confidence"))
                or None,
            }
        )

    return records


def _build_summary(results: pd.DataFrame, matched: pd.DataFrame) -> dict[str, Any]:
    """
    Build cohort-level counts from a tiered ranking table.

    Args:
        results: Tiered V6 ranking dataframe.
        matched: The same dataframe after external evidence matching.

    Returns:
        Summary counts for the response schema.
    """
    priority_counts = results["priority_v4"].value_counts()
    externally_supported = 0
    if "external_sources" in matched.columns:
        externally_supported = int(
            matched["external_sources"].fillna("").astype(str).str.strip().ne("").sum()
        )

    return {
        "total_targets": int(len(results)),
        "high_priority_count": int(priority_counts.get("High", 0)),
        "medium_priority_count": int(priority_counts.get("Medium", 0)),
        "low_priority_count": int(priority_counts.get("Low", 0)),
        "evidence_tier_counts": {
            str(row["evidence_tier_v6"]): int(row["target_count"])
            for _, row in create_tier_summary(results).iterrows()
        },
        "target_category_counts": {
            str(row["target_category_v6"]): int(row["target_count"])
            for _, row in create_category_summary(results).iterrows()
        },
        "externally_supported_targets": externally_supported,
    }


def _run_pipeline_from_inputs(
    mutations: pd.DataFrame, rna: pd.DataFrame
) -> pd.DataFrame:
    """
    Run the full ranking pipeline over caller-supplied mutation and RNA tables.

    Args:
        mutations: Mutation table with the columns required by the feature layer.
        rna: RNA expression matrix with a ``gene_name`` column.

    Returns:
        Tiered V6 ranking dataframe equivalent to the batch pipeline output.
    """
    safety_features = _read_cached_csv(SAFETY_FEATURES_FILE)

    try:
        features = build_target_feature_table(mutations=mutations, rna=rna)
        ranked_v3 = add_ranking_explanations_v3(rank_targets_v3(features))
        ranked_v4 = add_ranking_explanations_v4(
            rank_targets_v4_with_safety(ranked_v3, safety_features)
        )
    except ValueError as error:
        raise AnalysisInputError(str(error)) from error

    return add_evidence_tiers_v6(ranked_v4)


def _read_uploaded_csv(path: Path, label: str) -> pd.DataFrame:
    """
    Parse an uploaded CSV file into a dataframe.

    Args:
        path: Temporary path holding the uploaded bytes.
        label: Human-readable input name used in error messages.

    Returns:
        Parsed dataframe.
    """
    try:
        table = pd.read_csv(path, low_memory=False)
    except Exception as error:  # noqa: BLE001 - surfaced as a client-side input error
        raise AnalysisInputError(
            f"The {label} file could not be parsed as CSV."
        ) from error

    if table.empty:
        raise AnalysisInputError(f"The {label} file contains no rows.")

    return table


def _write_run_artifacts(
    run_id: str, results: pd.DataFrame, payload: dict[str, Any], top_n: int
) -> None:
    """
    Persist the Markdown report and JSON payload for one analysis run.

    The report is written first so its location can be recorded in the payload,
    keeping a replayed run identical to the original response.

    Args:
        run_id: Identifier of the analysis run.
        results: Tiered V6 ranking dataframe for the run.
        payload: Response payload, updated in place with the report location.
        top_n: Number of targets included in the report table.
    """
    run_dir = RUNS_DIR / run_id
    run_dir.mkdir(parents=True, exist_ok=True)

    report_path = create_markdown_report(
        results, run_dir / "target_ranking_report.md", top_n=top_n
    )
    payload["report_path"] = str(report_path)
    payload["report_url"] = f"/reports/{run_id}"

    (run_dir / "result.json").write_text(
        json.dumps(payload, indent=2), encoding="utf-8"
    )


def build_metrics_payload() -> dict[str, Any]:
    """
    Build the ML metrics payload from persisted benchmark outputs.

    Returns:
        The ``ml_metrics`` payload.
    """
    return build_ml_metrics_payload(METRICS_FILES)


def describe_readiness() -> dict[str, Any]:
    """
    Describe which pipeline artifacts the service can currently serve.

    Returns:
        Readiness flags and the list of missing artifact filenames.
    """
    required = {
        "cohort_ranking": RANKING_V6_FILE,
        "safety_features": SAFETY_FEATURES_FILE,
        "consensus_metrics": CONSENSUS_METRICS_FILE,
    }
    missing = [path.name for path in required.values() if not path.exists()]
    metrics = build_metrics_payload()

    return {
        "cohort_ranking_available": RANKING_V6_FILE.exists(),
        "metrics_available": bool(metrics.get("available")),
        "missing_artifacts": missing,
    }


def run_analysis(
    mutations_path: Path | None = None,
    expression_path: Path | None = None,
    top_n: int = DEFAULT_TOP_N,
) -> dict[str, Any]:
    """
    Run genomic target prioritization and build the research-use report.

    When both input files are supplied the full pipeline is executed over them.
    When neither is supplied the service reports on the pre-computed reference
    cohort produced by the batch pipeline.

    Args:
        mutations_path: Optional path to an uploaded mutation CSV.
        expression_path: Optional path to an uploaded RNA expression CSV.
        top_n: Number of ranked targets to return.

    Returns:
        Analysis payload matching ``AnalyzeResponse``.
    """
    if not 1 <= top_n <= MAX_TOP_N:
        raise AnalysisInputError(f"top_n must be between 1 and {MAX_TOP_N}.")

    if bool(mutations_path) != bool(expression_path):
        raise AnalysisInputError(
            "Both a mutation file and an RNA expression file are required to "
            "analyse uploaded data."
        )

    run_id = uuid4().hex
    generated_at = datetime.now(timezone.utc).isoformat()

    if mutations_path and expression_path:
        mutations = _read_uploaded_csv(mutations_path, "mutation")
        rna = _read_uploaded_csv(expression_path, "RNA expression")
        results = _run_pipeline_from_inputs(mutations, rna)
        data_source = "uploaded_files"
        inputs = {
            "mutation_rows": int(len(mutations)),
            "expression_genes": int(len(rna)),
            "expression_samples": int(
                max(len(rna.columns) - 1, 0)
            ),
        }
    else:
        results = load_v6_results(RANKING_V6_FILE)
        data_source = "precomputed_cohort"
        inputs = {
            "cohort_file": RANKING_V6_FILE.name,
            "note": (
                "No files were uploaded, so the pre-computed reference cohort "
                "ranking produced by the batch pipeline was reported."
            ),
        }

    matched = _match_external_evidence(results)
    top_targets = _restore_context_columns(
        create_top_targets_table(matched, top_n=top_n), matched
    )

    payload: dict[str, Any] = {
        "status": "success",
        "run_id": run_id,
        "data_source": data_source,
        "inputs": inputs,
        "generated_at": generated_at,
        "top_targets": _build_ranked_targets(top_targets),
        "summary": _build_summary(results, matched),
        "ml_metrics": build_metrics_payload(),
    }

    _write_run_artifacts(run_id, results, payload, top_n)

    return payload


def load_run_payload(run_id: str) -> dict[str, Any] | None:
    """
    Load a stored analysis payload by run id.

    Args:
        run_id: Identifier returned by ``run_analysis``.

    Returns:
        The stored payload, or ``None`` when the run is unknown.
    """
    if not run_id.isalnum():
        return None

    result_file = RUNS_DIR / run_id / "result.json"
    if not result_file.exists():
        return None

    return json.loads(result_file.read_text(encoding="utf-8"))


def load_run_report(run_id: str) -> str | None:
    """
    Load the Markdown report for a stored run.

    Args:
        run_id: Identifier returned by ``run_analysis``.

    Returns:
        The Markdown report text, or ``None`` when the run is unknown.
    """
    if not run_id.isalnum():
        return None

    report_file = RUNS_DIR / run_id / "target_ranking_report.md"
    if not report_file.exists():
        return None

    return report_file.read_text(encoding="utf-8")


def ensure_output_directories() -> None:
    """Create the report output directories used by the API."""
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    RUNS_DIR.mkdir(parents=True, exist_ok=True)
