// Implements genomic target prioritization workflows and FastAPI integration.
const { openAsBlob } = require("fs");
const path = require("path");
const { AppError } = require("../../../common/errors/AppError");

const FRONTEND_AI_UNAVAILABLE_MESSAGE = "AI service is temporarily unavailable.";
const FRONTEND_INPUT_ERROR_MESSAGE =
  "The uploaded genomic data could not be analyzed. Check the mutation and RNA expression files and try again.";
const FRONTEND_RESULT_NOT_FOUND_MESSAGE = "No analysis result was found for this run.";

const RESEARCH_USE_DISCLAIMER =
  "Research-use only. This service does not provide diagnosis or treatment decisions.";

const HEALTH_TIMEOUT_MS = Number.parseInt(
  process.env.AI_GENOMIC_HEALTH_TIMEOUT_MS || "8000",
  10,
);
const ANALYZE_TIMEOUT_MS = Number.parseInt(
  process.env.AI_GENOMIC_ANALYZE_TIMEOUT_MS || "180000",
  10,
);
const RESULTS_TIMEOUT_MS = Number.parseInt(
  process.env.AI_GENOMIC_RESULTS_TIMEOUT_MS || "20000",
  10,
);

const METRIC_FIELDS = [
  "accuracy",
  "balancedAccuracy",
  "precision",
  "recall",
  "f1Score",
  "mcc",
  "rocAuc",
  "prAuc",
];

function getFastApiBaseUrl() {
  return (
    process.env.AI_GENOMIC_TARGETS_BASE_URL ||
    process.env.AI_SERVICE_URL ||
    "http://127.0.0.1:8001"
  ).replace(/\/+$/, "");
}

function isPlainObject(value) {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

function toFiniteNumber(value) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value.trim());
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

function toTrimmedString(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed || null;
}

async function readJsonSafe(response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

// Maps an upstream failure onto a frontend-safe error without leaking AI service internals.
function throwUpstreamError(status, fallbackCode) {
  if (status === 400 || status === 422) {
    throw new AppError(
      FRONTEND_INPUT_ERROR_MESSAGE,
      400,
      "GENOMIC_ANALYSIS_INPUT_INVALID",
    );
  }

  if (status === 413) {
    throw new AppError(
      "The uploaded genomic data files are too large for the AI service.",
      413,
      "GENOMIC_ANALYSIS_PAYLOAD_TOO_LARGE",
    );
  }

  if (status === 404) {
    throw new AppError(
      FRONTEND_RESULT_NOT_FOUND_MESSAGE,
      404,
      "GENOMIC_ANALYSIS_RESULT_NOT_FOUND",
    );
  }

  throw new AppError(
    FRONTEND_AI_UNAVAILABLE_MESSAGE,
    status >= 500 ? 503 : 502,
    fallbackCode,
  );
}

// Calls the FastAPI AI service and converts transport failures into service errors.
async function requestAiService(endpoint, { method = "GET", body, timeoutMs }) {
  let response;

  try {
    response = await fetch(`${getFastApiBaseUrl()}${endpoint}`, {
      method,
      body,
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (error) {
    if (error?.name === "TimeoutError") {
      throw new AppError(
        "The AI service did not respond in time. Please try again.",
        504,
        "AI_SERVICE_TIMEOUT",
      );
    }

    throw new AppError(
      FRONTEND_AI_UNAVAILABLE_MESSAGE,
      503,
      "AI_SERVICE_UNAVAILABLE",
    );
  }

  return response;
}

// Converts one upstream ranked target into the frontend response shape.
function buildTargetResponse(target) {
  return {
    rank: toFiniteNumber(target?.rank),
    gene: toTrimmedString(target?.gene) || "Unknown",
    rankingScore: toFiniteNumber(target?.ranking_score),
    priority: toTrimmedString(target?.priority) || "Low",
    evidenceTier: toTrimmedString(target?.evidence_tier) || "Unknown",
    targetCategory: toTrimmedString(target?.target_category) || "Unknown",
    safetyRisk: toTrimmedString(target?.safety_risk) || "Unknown",
    safetyScore: toFiniteNumber(target?.safety_score),
    safetyNote: toTrimmedString(target?.safety_note),
    normalLungTpm: toFiniteNumber(target?.normal_lung_tpm),
    explanation: toTrimmedString(target?.explanation) || "",
    evidenceTierExplanation: toTrimmedString(target?.evidence_tier_explanation),
    externalEvidenceSources: Array.isArray(target?.external_evidence_sources)
      ? target.external_evidence_sources.map(String)
      : [],
    externalEvidenceConfidence: toTrimmedString(target?.external_evidence_confidence),
  };
}

// Converts upstream evaluation metrics into the frontend response shape.
function buildMetricsResponse(metrics) {
  const source = isPlainObject(metrics) ? metrics : {};
  const availability = isPlainObject(source.metrics_available)
    ? source.metrics_available
    : {};

  const values = {
    accuracy: toFiniteNumber(source.accuracy),
    balancedAccuracy: toFiniteNumber(source.balanced_accuracy),
    precision: toFiniteNumber(source.precision),
    recall: toFiniteNumber(source.recall),
    f1Score: toFiniteNumber(source.f1_score),
    mcc: toFiniteNumber(source.mcc),
    rocAuc: toFiniteNumber(source.roc_auc),
    prAuc: toFiniteNumber(source.pr_auc),
  };

  return {
    ...values,
    available: source.available === true,
    unavailableMetrics: METRIC_FIELDS.filter((field) => values[field] === null),
    modelName: toTrimmedString(source.model_name),
    labelMode: toTrimmedString(source.label_mode),
    benchmark: toTrimmedString(source.benchmark),
    evaluationStrategy: toTrimmedString(source.evaluation_strategy),
    labeledGenes: toFiniteNumber(source.n_genes),
    positiveGenes: toFiniteNumber(source.positive_genes),
    negativeGenes: toFiniteNumber(source.negative_genes),
    primaryModelSelectionRule: toTrimmedString(source.primary_model_selection_rule),
    metricsAvailable: {
      accuracy: availability.accuracy === true,
      balancedAccuracy: availability.balanced_accuracy === true,
      precision: availability.precision === true,
      recall: availability.recall === true,
      f1Score: availability.f1_score === true,
      mcc: availability.mcc === true,
      rocAuc: availability.roc_auc === true,
      prAuc: availability.pr_auc === true,
    },
  };
}

// Converts the upstream cohort summary into the frontend response shape.
function buildSummaryResponse(summary) {
  const source = isPlainObject(summary) ? summary : {};

  return {
    totalTargets: toFiniteNumber(source.total_targets) ?? 0,
    highPriorityCount: toFiniteNumber(source.high_priority_count) ?? 0,
    mediumPriorityCount: toFiniteNumber(source.medium_priority_count) ?? 0,
    lowPriorityCount: toFiniteNumber(source.low_priority_count) ?? 0,
    externallySupportedTargets:
      toFiniteNumber(source.externally_supported_targets) ?? 0,
    evidenceTierCounts: isPlainObject(source.evidence_tier_counts)
      ? source.evidence_tier_counts
      : {},
    targetCategoryCounts: isPlainObject(source.target_category_counts)
      ? source.target_category_counts
      : {},
  };
}

// Builds the frontend analysis payload, hiding AI service filesystem paths.
function buildAnalysisResponse(upstream) {
  const runId = toTrimmedString(upstream?.run_id);
  const reportPath = toTrimmedString(upstream?.report_path);

  return {
    runId,
    status: toTrimmedString(upstream?.status) || "success",
    dataSource: toTrimmedString(upstream?.data_source) || "precomputed_cohort",
    generatedAt: toTrimmedString(upstream?.generated_at),
    inputs: isPlainObject(upstream?.inputs) ? upstream.inputs : {},
    topTargets: Array.isArray(upstream?.top_targets)
      ? upstream.top_targets.map(buildTargetResponse)
      : [],
    summary: buildSummaryResponse(upstream?.summary),
    mlMetrics: buildMetricsResponse(upstream?.ml_metrics),
    reportAvailable: !!reportPath,
    reportFileName: reportPath ? path.basename(reportPath) : null,
    reportUrl: runId
      ? `/api/ai/genomic-target-prioritization/results/${runId}/report`
      : null,
    disclaimer: toTrimmedString(upstream?.disclaimer) || RESEARCH_USE_DISCLAIMER,
  };
}

// Executes the "check genomic target prioritization AI service health" workflow.
async function checkHealth() {
  const response = await requestAiService("/health", {
    timeoutMs: HEALTH_TIMEOUT_MS,
  });

  if (!response.ok) {
    throw new AppError(
      FRONTEND_AI_UNAVAILABLE_MESSAGE,
      503,
      "AI_SERVICE_UNAVAILABLE",
    );
  }

  const payload = await readJsonSafe(response);
  const isHealthy =
    payload?.ok === true || String(payload?.status || "").toLowerCase() === "ok";

  if (!isHealthy) {
    throw new AppError(
      FRONTEND_AI_UNAVAILABLE_MESSAGE,
      503,
      "AI_HEALTHCHECK_FAILED",
    );
  }

  return {
    available: true,
    service: toTrimmedString(payload?.service),
    version: toTrimmedString(payload?.version),
    metricsAvailable: payload?.metrics_available === true,
    cohortRankingAvailable: payload?.cohort_ranking_available === true,
  };
}

// Executes the "run genomic target prioritization analysis" workflow.
async function analyze({ topN, mutationsFile, expressionFile }) {
  await checkHealth();

  const form = new FormData();

  if (mutationsFile && expressionFile) {
    form.append(
      "mutations_file",
      await openAsBlob(mutationsFile.path),
      mutationsFile.originalname || "mutations.csv",
    );
    form.append(
      "expression_file",
      await openAsBlob(expressionFile.path),
      expressionFile.originalname || "expression.csv",
    );
  }

  const response = await requestAiService(`/analyze?top_n=${topN}`, {
    method: "POST",
    body: form,
    timeoutMs: ANALYZE_TIMEOUT_MS,
  });

  if (!response.ok) {
    throwUpstreamError(response.status, "GENOMIC_ANALYSIS_FAILED");
  }

  const payload = await readJsonSafe(response);
  if (!isPlainObject(payload)) {
    throw new AppError(
      FRONTEND_AI_UNAVAILABLE_MESSAGE,
      502,
      "GENOMIC_ANALYSIS_INVALID_RESPONSE",
    );
  }

  return buildAnalysisResponse(payload);
}

// Executes the "get a stored genomic target prioritization result" workflow.
async function getResult(runId) {
  const response = await requestAiService(`/results/${encodeURIComponent(runId)}`, {
    timeoutMs: RESULTS_TIMEOUT_MS,
  });

  if (!response.ok) {
    throwUpstreamError(response.status, "GENOMIC_ANALYSIS_RESULT_FAILED");
  }

  const payload = await readJsonSafe(response);
  if (!isPlainObject(payload)) {
    throw new AppError(
      FRONTEND_AI_UNAVAILABLE_MESSAGE,
      502,
      "GENOMIC_ANALYSIS_INVALID_RESPONSE",
    );
  }

  return buildAnalysisResponse(payload);
}

// Executes the "get the generated research report for a run" workflow.
async function getResultReport(runId) {
  const response = await requestAiService(`/reports/${encodeURIComponent(runId)}`, {
    timeoutMs: RESULTS_TIMEOUT_MS,
  });

  if (!response.ok) {
    throwUpstreamError(response.status, "GENOMIC_ANALYSIS_REPORT_FAILED");
  }

  return response.text();
}

module.exports = {
  checkHealth,
  analyze,
  getResult,
  getResultReport,
};
