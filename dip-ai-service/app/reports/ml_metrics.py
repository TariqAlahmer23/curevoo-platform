"""Read persisted model-evaluation metrics for the prioritization API.

Metrics are only ever read from the evaluation CSVs written by the benchmark
scripts (``scripts/run_civic_consensus_benchmark.py`` and
``scripts/run_leakage_minimized_ncg_classifier.py``). Nothing here computes,
estimates, or substitutes a metric value: rows that a benchmark marked as
``SKIPPED`` are reported as unavailable rather than filled in.
"""

from pathlib import Path
from typing import Any

import pandas as pd


# Reported per model run. ``accuracy`` is included because it is produced by the
# benchmark scripts; when a run did not produce it the value stays ``None``.
METRIC_FIELDS = [
    "accuracy",
    "balanced_accuracy",
    "precision",
    "recall",
    "f1_score",
    "mcc",
    "roc_auc",
    "pr_auc",
]

CONTEXT_FIELDS = [
    "evaluation_strategy",
    "n_genes",
    "positive_genes",
    "negative_genes",
]

INTEGER_CONTEXT_FIELDS = {"n_genes", "positive_genes", "negative_genes"}

# The headline model is chosen by Matthews correlation coefficient, which stays
# meaningful under the class imbalance of the gene-label datasets. The rule is
# reported back to the caller so the choice is auditable rather than implicit.
PRIMARY_MODEL_SELECTION_RULE = "highest_mcc_among_completed_evaluations"


def _to_optional_float(value: Any) -> float | None:
    """Return a finite float, or ``None`` when the source cell has no value."""
    number = pd.to_numeric(value, errors="coerce")
    if pd.isna(number):
        return None

    return float(number)


def _to_optional_int(value: Any) -> int | None:
    """Return an int, or ``None`` when the source cell has no value."""
    number = pd.to_numeric(value, errors="coerce")
    if pd.isna(number):
        return None

    return int(number)


def _to_optional_text(value: Any) -> str | None:
    """Return trimmed text, or ``None`` when the source cell is empty."""
    if value is None or pd.isna(value):
        return None

    text = str(value).strip()

    return text or None


def _read_metrics_file(path: Path, benchmark: str) -> list[dict[str, Any]]:
    """
    Read one benchmark metrics CSV into evaluation records.

    Args:
        path: Path to a metrics CSV written by a benchmark script.
        benchmark: Benchmark identifier reported with every record.

    Returns:
        One record per evaluated model, empty when the file is absent.
    """
    if not path.exists():
        return []

    metrics = pd.read_csv(path)
    records: list[dict[str, Any]] = []

    for _, row in metrics.iterrows():
        status = _to_optional_text(row.get("status")) or "UNKNOWN"
        record: dict[str, Any] = {
            "benchmark": benchmark,
            "label_mode": _to_optional_text(row.get("label_mode")),
            "model_name": _to_optional_text(row.get("model_name"))
            or _to_optional_text(row.get("model")),
            "status": status,
            "warning": _to_optional_text(row.get("warning")),
            "source_file": path.name,
        }

        for field in METRIC_FIELDS:
            record[field] = _to_optional_float(row.get(field))

        for field in CONTEXT_FIELDS:
            record[field] = (
                _to_optional_int(row.get(field))
                if field in INTEGER_CONTEXT_FIELDS
                else _to_optional_text(row.get(field))
            )

        records.append(record)

    return records


def load_evaluation_records(paths: dict[str, Path]) -> list[dict[str, Any]]:
    """
    Load every persisted evaluation record from the given metrics files.

    Args:
        paths: Mapping of benchmark identifier to metrics CSV path.

    Returns:
        Evaluation records across all available benchmark files.
    """
    records: list[dict[str, Any]] = []
    for benchmark, path in paths.items():
        records.extend(_read_metrics_file(path, benchmark))

    return records


def select_primary_evaluation(
    records: list[dict[str, Any]],
) -> dict[str, Any] | None:
    """
    Select the headline evaluation record.

    Args:
        records: Evaluation records loaded from the metrics files.

    Returns:
        The completed evaluation with the highest MCC, or ``None`` when no
        evaluation completed with a usable MCC.
    """
    completed = [
        record
        for record in records
        if record.get("status") == "OK" and record.get("mcc") is not None
    ]
    if not completed:
        return None

    return max(completed, key=lambda record: record["mcc"])


def build_ml_metrics_payload(paths: dict[str, Path]) -> dict[str, Any]:
    """
    Build the ``ml_metrics`` payload returned by the prioritization API.

    Args:
        paths: Mapping of benchmark identifier to metrics CSV path.

    Returns:
        Payload holding the headline metric values, the metric availability
        map, and the full benchmark table. Metrics that were never computed are
        returned as ``None`` and flagged in ``metrics_available``.
    """
    records = load_evaluation_records(paths)
    primary = select_primary_evaluation(records)

    metric_values: dict[str, float | None] = {
        field: (primary or {}).get(field) for field in METRIC_FIELDS
    }
    unavailable = [field for field, value in metric_values.items() if value is None]

    return {
        **metric_values,
        "available": primary is not None,
        "metrics_available": {
            field: value is not None for field, value in metric_values.items()
        },
        "unavailable_metrics": unavailable,
        "model_name": (primary or {}).get("model_name"),
        "label_mode": (primary or {}).get("label_mode"),
        "benchmark": (primary or {}).get("benchmark"),
        "evaluation_strategy": (primary or {}).get("evaluation_strategy"),
        "n_genes": (primary or {}).get("n_genes"),
        "positive_genes": (primary or {}).get("positive_genes"),
        "negative_genes": (primary or {}).get("negative_genes"),
        "primary_model_selection_rule": PRIMARY_MODEL_SELECTION_RULE,
        "evaluations": records,
    }
