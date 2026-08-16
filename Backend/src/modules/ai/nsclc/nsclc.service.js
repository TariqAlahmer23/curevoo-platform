// Implements NSCLC prediction workflows and FastAPI integration.
const { AppError } = require("../../../common/errors/AppError");
const {
  findDoctorAccessiblePatientContext,
  createNsclcPredictionRun,
  createNsclcPredictionRunForCreatedPatient,
  findLatestNsclcPredictionRunForPatient,
  findLatestNsclcPredictionRunForCreatedPatient,
} = require("./nsclc.repo");

const NSCLC_PACKAGE_SLUG = "nsclc";
const FRONTEND_DATA_ERROR_MESSAGE =
  "This patient does not have enough NSCLC treatment data for prediction.";
const FRONTEND_NSCLC_ONLY_ERROR_MESSAGE =
  "This prediction is only available for lung NSCLC patients.";
const FRONTEND_AI_UNAVAILABLE_MESSAGE = "AI service is temporarily unavailable.";

const NSCLC_PAYLOAD_FIELDS = [
  "age_feature",
  "sex",
  "institution",
  "stage_dx",
  "advanced_stage_flag",
  "histology_group",
  "smoking_status_group",
  "regimen_category",
  "index_regimen_number",
  "n_regimens_pt",
  "prior_systemic_therapy_count",
  "prior_egfr_targeted_exposure",
  "prior_therapy_class_summary",
  "sequencing_before_regimen_flag",
  "sequencing_close_to_regimen_start_flag",
  "large_sequencing_gap_flag",
  "n_imaging_reports_pt",
  "n_md_notes_pt",
  "EGFR",
  "EGFR_exon19del_flag",
  "EGFR_L858R_flag",
  "EGFR_T790M_flag",
  "EGFR_subtype_group",
  "KRAS",
  "BRAF",
  "MET",
  "ERBB2",
  "PIK3CA",
  "TP53",
  "RB1",
  "STK11",
  "KEAP1",
  "PTEN",
  "CDKN2A",
  "co_mutation_count",
  "tumor_suppressor_loss_count",
  "bypass_pathway_burden",
  "bypass_pathway_flag",
  "cell_cycle_flag",
  "TP53_RB1_double_hit_flag",
  "STK11_KEAP1_double_hit_flag",
];

const NSCLC_ALLOWED_OVERRIDE_FIELDS = new Set(NSCLC_PAYLOAD_FIELDS);
const NSCLC_REQUIRED_FIELDS = [
  "age_feature",
  "sex",
  "stage_dx",
  "histology_group",
  "smoking_status_group",
  "regimen_category",
  "EGFR",
];

const NSCLC_FLAG_FIELDS = [
  "advanced_stage_flag",
  "prior_egfr_targeted_exposure",
  "sequencing_before_regimen_flag",
  "sequencing_close_to_regimen_start_flag",
  "large_sequencing_gap_flag",
  "EGFR",
  "EGFR_exon19del_flag",
  "EGFR_L858R_flag",
  "EGFR_T790M_flag",
  "KRAS",
  "BRAF",
  "MET",
  "ERBB2",
  "PIK3CA",
  "TP53",
  "RB1",
  "STK11",
  "KEAP1",
  "PTEN",
  "CDKN2A",
  "bypass_pathway_flag",
  "cell_cycle_flag",
  "TP53_RB1_double_hit_flag",
  "STK11_KEAP1_double_hit_flag",
];

const NSCLC_INTEGER_FIELDS = [
  "age_feature",
  "index_regimen_number",
  "n_regimens_pt",
  "prior_systemic_therapy_count",
  "n_imaging_reports_pt",
  "n_md_notes_pt",
  "co_mutation_count",
  "tumor_suppressor_loss_count",
  "bypass_pathway_burden",
];

const NSCLC_MUTATION_FLAG_FIELDS = [
  "KRAS",
  "BRAF",
  "MET",
  "ERBB2",
  "PIK3CA",
  "TP53",
  "RB1",
  "STK11",
  "KEAP1",
  "PTEN",
  "CDKN2A",
];

const NSCLC_TUMOR_SUPPRESSOR_FIELDS = ["TP53", "RB1", "STK11", "KEAP1", "PTEN", "CDKN2A"];
const NSCLC_BYPASS_FIELDS = ["KRAS", "BRAF", "MET", "ERBB2", "PIK3CA"];

const NSCLC_FIELD_ALIASES = {
  age_feature: ["age", "age_at_sequencing"],
  institution: ["working_at", "workingAt", "hospital", "center", "site"],
  advanced_stage_flag: ["advanced_stage", "advanced_stage_ind"],
  index_regimen_number: ["regimen_index", "line_of_therapy", "line_number"],
  n_regimens_pt: ["n_regimens", "number_of_regimens"],
  prior_systemic_therapy_count: ["prior_therapy_count", "previous_systemic_therapy_count"],
  sequencing_close_to_regimen_start_flag: ["sequencing_close_flag", "matched_ca_seq_flag"],
  large_sequencing_gap_flag: ["sequencing_gap_large_flag", "sequencing_large_gap_flag"],
  prior_egfr_targeted_exposure: ["prior_egfr_exposure"],
  n_imaging_reports_pt: ["imaging_reports_count", "n_imaging_reports"],
  n_md_notes_pt: ["md_notes_count", "n_md_notes"],
};

function getFastApiBaseUrl() {
  return (
    process.env.AI_NSCLC_BASE_URL ||
    process.env.AI_FASTAPI_BASE_URL ||
    "http://127.0.0.1:8000"
  ).replace(/\/+$/, "");
}

function isPlainObject(value) {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

function normalizeKey(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]/g, "");
}

function toCamelCase(snakeCase) {
  return String(snakeCase || "").replace(/_([a-z0-9])/g, (_, char) =>
    String(char).toUpperCase(),
  );
}

function toTrimmedString(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed || null;
}

function toFiniteNumber(value) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value.trim());
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

function toInteger(value) {
  const numeric = toFiniteNumber(value);
  if (numeric === null) return null;
  return Math.trunc(numeric);
}

function toFlag(value) {
  if (typeof value === "boolean") return value ? 1 : 0;

  if (typeof value === "number") {
    if (value === 0) return 0;
    if (value === 1) return 1;
  }

  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (!normalized) return null;

    if (
      normalized === "1" ||
      normalized === "true" ||
      normalized === "yes" ||
      normalized === "y" ||
      normalized === "positive" ||
      normalized === "present" ||
      normalized === "detected" ||
      normalized === "mutated"
    ) {
      return 1;
    }

    if (
      normalized === "0" ||
      normalized === "false" ||
      normalized === "no" ||
      normalized === "n" ||
      normalized === "negative" ||
      normalized === "absent" ||
      normalized === "not detected" ||
      normalized === "wildtype"
    ) {
      return 0;
    }
  }

  return null;
}

function normalizeSex(value) {
  const normalized = toTrimmedString(value)?.toLowerCase();
  if (!normalized) return null;
  if (normalized === "male" || normalized === "m") return "Male";
  if (normalized === "female" || normalized === "f") return "Female";
  if (normalized === "other" || normalized === "o") return "Other";
  return value;
}

function normalizeObjectKeysToNsclcFields(input) {
  if (!isPlainObject(input)) return {};

  const normalizedFieldMap = NSCLC_PAYLOAD_FIELDS.reduce((acc, field) => {
    acc[normalizeKey(field)] = field;
    acc[normalizeKey(toCamelCase(field))] = field;
    return acc;
  }, {});

  const output = {};
  for (const [key, value] of Object.entries(input)) {
    const mappedField = normalizedFieldMap[normalizeKey(key)];
    if (mappedField) output[mappedField] = value;
  }
  return output;
}

function findValueByNormalizedKey(source, normalizedCandidate, visited = new Set()) {
  if (source === null || source === undefined) return undefined;

  if (isPlainObject(source)) {
    if (visited.has(source)) return undefined;
    visited.add(source);

    for (const [key, value] of Object.entries(source)) {
      if (normalizeKey(key) === normalizedCandidate) return value;
    }

    for (const value of Object.values(source)) {
      const nested = findValueByNormalizedKey(value, normalizedCandidate, visited);
      if (nested !== undefined) return nested;
    }

    return undefined;
  }

  if (Array.isArray(source)) {
    for (const item of source) {
      const nested = findValueByNormalizedKey(item, normalizedCandidate, visited);
      if (nested !== undefined) return nested;
    }
  }

  return undefined;
}

function buildNsclcPayloadCandidates(context) {
  const patient = context?.patient || {};
  const patientProfile = patient?.patientProfile || {};
  const medicalHistoryRecord = patient?.medicalHistories?.[0]?.record || null;
  const treatmentPlan = patient?.treatmentPlansAsPatient?.[0]?.treatmentPlan || null;
  const symptomsLog = patient?.treatmentPlansAsPatient?.[0]?.symptomsLog || null;
  const treatmentRecord = patient?.treatmentRecords?.[0]?.record || null;
  const treatmentRecordDetectorResult =
    patient?.treatmentRecords?.[0]?.curevooDetectorResult || null;
  const testRecordData = patient?.testRecords?.[0]?.testRecordData || null;
  const cancerTestData = patient?.cancerTests?.[0]?.testEnteredData || null;
  const riskFactors = patientProfile?.riskFactors || null;

  const rawSources = [
    patientProfile,
    medicalHistoryRecord,
    treatmentPlan,
    symptomsLog,
    treatmentRecord,
    testRecordData,
    cancerTestData,
    riskFactors,
    treatmentRecordDetectorResult,
  ].filter((source) => isPlainObject(source));

  const normalizedSources = rawSources.map((source) =>
    normalizeObjectKeysToNsclcFields(source),
  );

  return [...rawSources, ...normalizedSources];
}

function pickValueFromCandidates(fieldName, candidates) {
  const aliases = [fieldName, ...(NSCLC_FIELD_ALIASES[fieldName] || [])];

  for (const alias of aliases) {
    const normalizedAlias = normalizeKey(alias);
    for (const candidate of candidates) {
      const value = findValueByNormalizedKey(candidate, normalizedAlias);
      if (value !== undefined && value !== null && value !== "") return value;
    }
  }

  return null;
}

function countFlagged(payload, fields) {
  return fields.reduce((acc, field) => acc + (payload[field] === 1 ? 1 : 0), 0);
}

function deriveNsclcFields(payload) {
  if (payload.advanced_stage_flag === null) {
    const normalizedStage = toTrimmedString(payload.stage_dx)?.toLowerCase() || "";
    if (
      normalizedStage.includes("iv") ||
      normalizedStage.includes("stage 4") ||
      normalizedStage.includes("metastatic")
    ) {
      payload.advanced_stage_flag = 1;
    } else if (normalizedStage) {
      payload.advanced_stage_flag = 0;
    }
  }

  if (!toTrimmedString(payload.EGFR_subtype_group)) {
    if (payload.EGFR_exon19del_flag === 1) payload.EGFR_subtype_group = "Exon19del";
    else if (payload.EGFR_L858R_flag === 1) payload.EGFR_subtype_group = "L858R";
    else if (payload.EGFR_T790M_flag === 1) payload.EGFR_subtype_group = "T790M";
  }

  if (payload.co_mutation_count === null) {
    payload.co_mutation_count = countFlagged(payload, NSCLC_MUTATION_FLAG_FIELDS);
  }

  if (payload.tumor_suppressor_loss_count === null) {
    payload.tumor_suppressor_loss_count = countFlagged(
      payload,
      NSCLC_TUMOR_SUPPRESSOR_FIELDS,
    );
  }

  if (payload.bypass_pathway_burden === null) {
    payload.bypass_pathway_burden = countFlagged(payload, NSCLC_BYPASS_FIELDS);
  }

  if (payload.bypass_pathway_flag === null && payload.bypass_pathway_burden !== null) {
    payload.bypass_pathway_flag = payload.bypass_pathway_burden > 0 ? 1 : 0;
  }

  if (payload.cell_cycle_flag === null) {
    payload.cell_cycle_flag =
      payload.RB1 === 1 || payload.CDKN2A === 1 ? 1 : payload.RB1 === 0 && payload.CDKN2A === 0 ? 0 : null;
  }

  if (payload.TP53_RB1_double_hit_flag === null) {
    payload.TP53_RB1_double_hit_flag =
      payload.TP53 === 1 && payload.RB1 === 1
        ? 1
        : payload.TP53 === 0 || payload.RB1 === 0
          ? 0
          : null;
  }

  if (payload.STK11_KEAP1_double_hit_flag === null) {
    payload.STK11_KEAP1_double_hit_flag =
      payload.STK11 === 1 && payload.KEAP1 === 1
        ? 1
        : payload.STK11 === 0 || payload.KEAP1 === 0
          ? 0
          : null;
  }
}

function normalizePayloadTypes(payload) {
  const normalized = { ...payload };

  for (const field of NSCLC_INTEGER_FIELDS) {
    normalized[field] = toInteger(normalized[field]);
  }

  for (const field of NSCLC_FLAG_FIELDS) {
    normalized[field] = toFlag(normalized[field]);
  }

  normalized.sex = normalizeSex(normalized.sex);
  normalized.institution = toTrimmedString(normalized.institution);
  normalized.stage_dx = toTrimmedString(normalized.stage_dx);
  normalized.histology_group = toTrimmedString(normalized.histology_group);
  normalized.smoking_status_group = toTrimmedString(normalized.smoking_status_group);
  normalized.regimen_category = toTrimmedString(normalized.regimen_category);
  normalized.prior_therapy_class_summary = toTrimmedString(
    normalized.prior_therapy_class_summary,
  );
  normalized.EGFR_subtype_group = toTrimmedString(normalized.EGFR_subtype_group);

  return normalized;
}

function ensurePatientIsNsclc(payload, contextCandidates) {
  const inferredCancerType = pickValueFromCandidates("cancer_type", contextCandidates);
  const inferredDiagnosis = pickValueFromCandidates("diagnosis", contextCandidates);
  const combined = [
    toTrimmedString(inferredCancerType),
    toTrimmedString(inferredDiagnosis),
    toTrimmedString(payload.histology_group),
  ]
    .filter(Boolean)
    .join(" ")
    .toLowerCase();

  if (!combined) return;

  const looksLikeNsclc =
    combined.includes("nsclc") ||
    combined.includes("non-small") ||
    combined.includes("adenocarcinoma") ||
    combined.includes("squamous");

  if (!looksLikeNsclc) {
    throw new AppError(
      FRONTEND_NSCLC_ONLY_ERROR_MESSAGE,
      400,
      "NSCLC_PATIENT_REQUIRED",
    );
  }
}

function ensureEgfrTargetedContext(payload) {
  const regimenCategory = toTrimmedString(payload.regimen_category)?.toLowerCase() || "";
  if (!regimenCategory.includes("egfr")) {
    throw new AppError(
      FRONTEND_DATA_ERROR_MESSAGE,
      400,
      "NSCLC_EGFR_CONTEXT_REQUIRED",
    );
  }
}

function ensureRequiredFields(payload) {
  const missing = NSCLC_REQUIRED_FIELDS.filter((field) => {
    const value = payload[field];
    return value === null || value === undefined || value === "";
  });

  if (missing.length) {
    throw new AppError(
      FRONTEND_DATA_ERROR_MESSAGE,
      400,
      "NSCLC_REQUIRED_FIELDS_MISSING",
    );
  }
}

function shouldIncludeLlmExplanation(requestedByFrontend) {
  const envToggle =
    process.env.NSCLC_LLM_EXPLANATION_ENABLED ||
    process.env.AI_NSCLC_LLM_EXPLANATION_ENABLED ||
    "false";
  return !!requestedByFrontend && String(envToggle).toLowerCase() === "true";
}

async function readJsonSafe(response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

async function checkFastApiHealth() {
  let response;

  try {
    response = await fetch(`${getFastApiBaseUrl()}/health`);
  } catch {
    throw new AppError(
      FRONTEND_AI_UNAVAILABLE_MESSAGE,
      503,
      "AI_SERVICE_UNAVAILABLE",
    );
  }

  if (!response.ok) {
    throw new AppError(
      FRONTEND_AI_UNAVAILABLE_MESSAGE,
      503,
      "AI_SERVICE_UNAVAILABLE",
    );
  }

  const payload = await readJsonSafe(response);
  const ok = payload?.ok === true || String(payload?.status || "").toLowerCase() === "ok";
  if (!ok) {
    throw new AppError(
      FRONTEND_AI_UNAVAILABLE_MESSAGE,
      503,
      "AI_HEALTHCHECK_FAILED",
    );
  }
}

async function checkNsclcModelAvailability() {
  let response;

  try {
    response = await fetch(`${getFastApiBaseUrl()}/models/${NSCLC_PACKAGE_SLUG}`);
  } catch {
    throw new AppError(
      FRONTEND_AI_UNAVAILABLE_MESSAGE,
      503,
      "AI_SERVICE_UNAVAILABLE",
    );
  }

  if (response.status === 404) {
    throw new AppError(
      FRONTEND_AI_UNAVAILABLE_MESSAGE,
      502,
      "NSCLC_MODEL_NOT_FOUND",
    );
  }

  if (!response.ok) {
    throw new AppError(
      FRONTEND_AI_UNAVAILABLE_MESSAGE,
      502,
      "AI_MODEL_QUERY_FAILED",
    );
  }
}

async function requestNsclcPrediction(body, includeLlmExplanation) {
  const query = includeLlmExplanation ? "?include_llm_explanation=true" : "";
  const endpoint = `${getFastApiBaseUrl()}/predict/${NSCLC_PACKAGE_SLUG}${query}`;

  let response;

  try {
    response = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
  } catch {
    throw new AppError(
      FRONTEND_AI_UNAVAILABLE_MESSAGE,
      503,
      "AI_SERVICE_UNAVAILABLE",
    );
  }

  const payload = await readJsonSafe(response);

  if (!response.ok) {
    if (response.status === 404) {
      throw new AppError(
        FRONTEND_AI_UNAVAILABLE_MESSAGE,
        502,
        "NSCLC_MODEL_NOT_FOUND",
      );
    }

    if (response.status === 400 || response.status === 422) {
      throw new AppError(
        FRONTEND_DATA_ERROR_MESSAGE,
        400,
        "NSCLC_PREDICTION_VALIDATION_FAILED",
      );
    }

    throw new AppError(
      FRONTEND_AI_UNAVAILABLE_MESSAGE,
      response.status >= 500 ? 503 : 502,
      "NSCLC_PREDICTION_FAILED",
    );
  }

  if (!isPlainObject(payload)) {
    throw new AppError(
      FRONTEND_AI_UNAVAILABLE_MESSAGE,
      502,
      "NSCLC_INVALID_RESPONSE",
    );
  }

  return payload;
}

function buildNsclcPayload(context, overrides = {}) {
  const candidateSources = buildNsclcPayloadCandidates(context);
  const patient = context?.patient || {};
  const doctor = context?.doctor || {};

  const payload = NSCLC_PAYLOAD_FIELDS.reduce((acc, field) => {
    acc[field] = pickValueFromCandidates(field, candidateSources);
    return acc;
  }, {});

  if (payload.age_feature === null) {
    payload.age_feature = patient?.patientProfile?.age ?? patient?.age ?? null;
  }

  if (payload.sex === null) {
    payload.sex = patient?.patientProfile?.sex || null;
  }

  if (payload.institution === null) {
    payload.institution = doctor?.doctorProfile?.workingAt || null;
  }

  const normalizedOverrides = normalizeObjectKeysToNsclcFields(overrides);
  for (const [field, value] of Object.entries(normalizedOverrides)) {
    if (!NSCLC_ALLOWED_OVERRIDE_FIELDS.has(field)) continue;
    payload[field] = value;
  }

  const normalized = normalizePayloadTypes(payload);
  deriveNsclcFields(normalized);
  ensurePatientIsNsclc(normalized, candidateSources);
  ensureEgfrTargetedContext(normalized);
  ensureRequiredFields(normalized);

  return normalized;
}

function buildFrontendPredictionResponse(runId, patientId, upstream, options = {}) {
  const resistanceInterpretation = upstream?.resistance_related_interpretation || {};
  const earlyFailureRisk = upstream?.early_failure_risk || {};
  const durableBenefitLikelihood = upstream?.durable_benefit_likelihood || {};
  const subjectType = options.subjectType || "NORMAL";

  return {
    predictionRunId: runId,
    patientId,
    patientType: subjectType,
    predictionRunStored: !!runId,
    packageSlug: NSCLC_PACKAGE_SLUG,
    cancerType: "NSCLC",
    predictionVersion: upstream?.version || null,
    summaryText: upstream?.summary_text || null,
    supportLabel: "Prediction support only. Not treatment instruction.",
    earlyFailureRisk: {
      title: earlyFailureRisk.public_result_label || "Predicted Early Progression Risk",
      probability: toFiniteNumber(earlyFailureRisk.probability),
      riskLevel: earlyFailureRisk.risk_level || null,
      subtitle: earlyFailureRisk.public_subtitle || null,
    },
    durableBenefitLikelihood: {
      title:
        durableBenefitLikelihood.public_result_label ||
        "Predicted Durable Benefit Signal",
      probability: toFiniteNumber(durableBenefitLikelihood.probability),
      riskLevel: durableBenefitLikelihood.risk_level || null,
      subtitle: durableBenefitLikelihood.public_subtitle || null,
    },
    resistanceInterpretation: {
      summary:
        resistanceInterpretation.summary ||
        resistanceInterpretation.deterministic_summary_text ||
        null,
      signals: Array.isArray(resistanceInterpretation.signals)
        ? resistanceInterpretation.signals
        : [],
    },
  };
}

// Executes the "predict NSCLC resistance support" workflow for this module.
async function predictNsclc(doctorUserId, data) {
  const context = await findDoctorAccessiblePatientContext(doctorUserId, data.patientId);
  if (!context?.patient) {
    throw new AppError("Patient not found", 404, "PATIENT_NOT_FOUND");
  }
  const isCreatedPatient = context.subjectType === "CREATED";

  const llmExplanationEnabled = shouldIncludeLlmExplanation(
    data.includeLlmExplanation,
  );
  const payload = buildNsclcPayload(context, data.overrides);
  const requestPayloadJson = {
    patient_id: data.patientId,
    patient_type: context.subjectType || "NORMAL",
    payload,
  };

  try {
    await checkFastApiHealth();
    await checkNsclcModelAvailability();

    const upstream = await requestNsclcPrediction(
      requestPayloadJson,
      llmExplanationEnabled,
    );

    if (
      upstream.package_slug &&
      String(upstream.package_slug).toLowerCase() !== NSCLC_PACKAGE_SLUG
    ) {
      throw new AppError(
        FRONTEND_AI_UNAVAILABLE_MESSAGE,
        502,
        "NSCLC_PACKAGE_MISMATCH",
      );
    }

    const predictionRun = isCreatedPatient
      ? await createNsclcPredictionRunForCreatedPatient({
          createdPatientId: data.patientId,
          doctorId: doctorUserId,
          predictionVersion: upstream.version ?? null,
          requestPayloadJson,
          responseJson: upstream,
          summaryText: upstream.summary_text ?? null,
          earlyFailureProbability: toFiniteNumber(upstream?.early_failure_risk?.probability),
          earlyFailureRiskLevel: upstream?.early_failure_risk?.risk_level ?? null,
          durableBenefitProbability: toFiniteNumber(
            upstream?.durable_benefit_likelihood?.probability,
          ),
          durableBenefitRiskLevel: upstream?.durable_benefit_likelihood?.risk_level ?? null,
          interpretationSummary:
            upstream?.resistance_related_interpretation?.summary ||
            upstream?.resistance_related_interpretation?.deterministic_summary_text ||
            null,
          llmExplanationEnabled,
          status: "SUCCESS",
          errorMessage: null,
        })
      : await createNsclcPredictionRun({
        patientId: data.patientId,
        doctorId: doctorUserId,
        predictionVersion: upstream.version ?? null,
        requestPayloadJson,
        responseJson: upstream,
        summaryText: upstream.summary_text ?? null,
        earlyFailureProbability: toFiniteNumber(upstream?.early_failure_risk?.probability),
        earlyFailureRiskLevel: upstream?.early_failure_risk?.risk_level ?? null,
        durableBenefitProbability: toFiniteNumber(
          upstream?.durable_benefit_likelihood?.probability,
        ),
        durableBenefitRiskLevel: upstream?.durable_benefit_likelihood?.risk_level ?? null,
        interpretationSummary:
          upstream?.resistance_related_interpretation?.summary ||
          upstream?.resistance_related_interpretation?.deterministic_summary_text ||
          null,
        llmExplanationEnabled,
        status: "SUCCESS",
        errorMessage: null,
      });

    return buildFrontendPredictionResponse(
      predictionRun.id,
      data.patientId,
      upstream,
      { subjectType: context.subjectType || "NORMAL" },
    );
  } catch (error) {
    try {
      if (isCreatedPatient) {
        await createNsclcPredictionRunForCreatedPatient({
          createdPatientId: data.patientId,
          doctorId: doctorUserId,
          predictionVersion: null,
          requestPayloadJson,
          responseJson: null,
          summaryText: null,
          earlyFailureProbability: null,
          earlyFailureRiskLevel: null,
          durableBenefitProbability: null,
          durableBenefitRiskLevel: null,
          interpretationSummary: null,
          llmExplanationEnabled,
          status: "FAILED",
          errorMessage: error?.message || "Unknown prediction error",
        });
      } else {
        await createNsclcPredictionRun({
          patientId: data.patientId,
          doctorId: doctorUserId,
          predictionVersion: null,
          requestPayloadJson,
          responseJson: null,
          summaryText: null,
          earlyFailureProbability: null,
          earlyFailureRiskLevel: null,
          durableBenefitProbability: null,
          durableBenefitRiskLevel: null,
          interpretationSummary: null,
          llmExplanationEnabled,
          status: "FAILED",
          errorMessage: error?.message || "Unknown prediction error",
        });
      }
    } catch {
      // Ignore persistence failures for failed prediction runs so the original error is returned.
    }

    throw error;
  }
}

// Executes the "get last NSCLC resistance support result" workflow.
async function getLastNsclcResult(doctorUserId, patientId) {
  const context = await findDoctorAccessiblePatientContext(doctorUserId, patientId);
  if (!context?.patient) {
    throw new AppError("Patient not found", 404, "PATIENT_NOT_FOUND");
  }

  const subjectType = context.subjectType || "NORMAL";
  const latestRun =
    subjectType === "CREATED"
      ? await findLatestNsclcPredictionRunForCreatedPatient(doctorUserId, patientId)
      : await findLatestNsclcPredictionRunForPatient(doctorUserId, patientId);

  if (!latestRun) {
    throw new AppError("No AI prediction result found", 404, "AI_RESULT_NOT_FOUND");
  }

  const responseJson =
    latestRun.responseJson && typeof latestRun.responseJson === "object"
      ? latestRun.responseJson
      : {};

  return {
    predictionRunId: latestRun.id,
    patientId,
    patientType: subjectType,
    predictionRunStored: true,
    packageSlug: NSCLC_PACKAGE_SLUG,
    cancerType: "NSCLC",
    predictionVersion: latestRun.predictionVersion || null,
    summaryText: latestRun.summaryText || null,
    supportLabel: "Prediction support only. Not treatment instruction.",
    earlyFailureRisk: {
      title:
        responseJson?.early_failure_risk?.public_result_label ||
        "Predicted Early Progression Risk",
      probability: latestRun.earlyFailureProbability,
      riskLevel: latestRun.earlyFailureRiskLevel,
      subtitle: responseJson?.early_failure_risk?.public_subtitle || null,
    },
    durableBenefitLikelihood: {
      title:
        responseJson?.durable_benefit_likelihood?.public_result_label ||
        "Predicted Durable Benefit Signal",
      probability: latestRun.durableBenefitProbability,
      riskLevel: latestRun.durableBenefitRiskLevel,
      subtitle: responseJson?.durable_benefit_likelihood?.public_subtitle || null,
    },
    resistanceInterpretation: {
      summary: latestRun.interpretationSummary || null,
      signals: Array.isArray(responseJson?.resistance_related_interpretation?.signals)
        ? responseJson.resistance_related_interpretation.signals
        : [],
    },
    createdAt: latestRun.createdAt,
  };
}

module.exports = {
  predictNsclc,
  getLastNsclcResult,
};
