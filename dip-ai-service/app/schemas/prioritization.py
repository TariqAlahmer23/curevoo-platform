"""Response schemas for the genomic target prioritization API."""

from typing import Any, Literal

from pydantic import BaseModel, Field


RESEARCH_USE_DISCLAIMER = (
    "Research-use only. This service does not provide diagnosis or treatment "
    "decisions."
)


class HealthResponse(BaseModel):
    """Service liveness and dataset-readiness report."""

    status: Literal["ok", "degraded"]
    ok: bool
    service: str
    version: str
    metrics_available: bool
    cohort_ranking_available: bool
    missing_artifacts: list[str] = Field(default_factory=list)


class ModelEvaluation(BaseModel):
    """One persisted model evaluation row from a benchmark metrics file."""

    benchmark: str | None = None
    label_mode: str | None = None
    model_name: str | None = None
    status: str
    accuracy: float | None = None
    balanced_accuracy: float | None = None
    precision: float | None = None
    recall: float | None = None
    f1_score: float | None = None
    mcc: float | None = None
    roc_auc: float | None = None
    pr_auc: float | None = None
    evaluation_strategy: str | None = None
    n_genes: int | None = None
    positive_genes: int | None = None
    negative_genes: int | None = None
    warning: str | None = None
    source_file: str | None = None


class MlMetrics(BaseModel):
    """
    Headline evaluation metrics read from persisted benchmark outputs.

    A ``None`` metric means the benchmark never produced that value. It is
    reported as unavailable rather than replaced with a substitute number.
    """

    accuracy: float | None = None
    balanced_accuracy: float | None = None
    precision: float | None = None
    recall: float | None = None
    f1_score: float | None = None
    mcc: float | None = None
    roc_auc: float | None = None
    pr_auc: float | None = None

    available: bool = False
    metrics_available: dict[str, bool] = Field(default_factory=dict)
    unavailable_metrics: list[str] = Field(default_factory=list)

    model_name: str | None = None
    label_mode: str | None = None
    benchmark: str | None = None
    evaluation_strategy: str | None = None
    n_genes: int | None = None
    positive_genes: int | None = None
    negative_genes: int | None = None
    primary_model_selection_rule: str | None = None
    evaluations: list[ModelEvaluation] = Field(default_factory=list)


class MetricsResponse(BaseModel):
    """Standalone ``GET /metrics`` payload."""

    status: Literal["success"] = "success"
    ml_metrics: MlMetrics
    disclaimer: str = RESEARCH_USE_DISCLAIMER


class RankedTarget(BaseModel):
    """One ranked candidate target in the research report."""

    rank: int
    gene: str
    ranking_score: float
    priority: Literal["High", "Medium", "Low"]
    evidence_tier: str
    target_category: str
    safety_risk: str
    safety_score: float | None = None
    safety_note: str | None = None
    normal_lung_tpm: float | None = None
    explanation: str
    evidence_tier_explanation: str | None = None
    external_evidence_sources: list[str] = Field(default_factory=list)
    external_evidence_confidence: str | None = None


class AnalysisSummary(BaseModel):
    """Cohort-level counts for the analysed target universe."""

    total_targets: int
    high_priority_count: int
    medium_priority_count: int
    low_priority_count: int
    evidence_tier_counts: dict[str, int] = Field(default_factory=dict)
    target_category_counts: dict[str, int] = Field(default_factory=dict)
    externally_supported_targets: int = 0


class AnalyzeResponse(BaseModel):
    """``POST /analyze`` payload returned to the backend."""

    status: Literal["success"] = "success"
    run_id: str
    data_source: Literal["uploaded_files", "precomputed_cohort"]
    inputs: dict[str, Any] = Field(default_factory=dict)
    generated_at: str
    top_targets: list[RankedTarget] = Field(default_factory=list)
    summary: AnalysisSummary
    ml_metrics: MlMetrics
    report_path: str | None = None
    report_url: str | None = None
    disclaimer: str = RESEARCH_USE_DISCLAIMER
