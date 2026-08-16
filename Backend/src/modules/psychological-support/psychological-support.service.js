// Implements psychological support workflows, Grace integration, and safe educational search.
const { AppError } = require("../../common/errors/AppError");
const repo = require("./psychological-support.repo");

const EDUCATIONAL_DISCLAIMER = "Educational information only. Not medical advice.";
const SAFE_REFUSAL_MESSAGE =
  "I cannot give treatment decisions, diagnosis, medication advice, or interpret your personal medical results. Please discuss this with your oncology team. I can explain general information about the topic if that helps.";
const CRISIS_REDIRECT_MESSAGE =
  "I am sorry you are feeling this way. Your safety matters. Please contact local emergency services now or reach out to a trusted person immediately. If available, contact a crisis hotline in your country.";
const NON_CANCER_SCOPE_MESSAGE =
  "This search is focused on general cancer education. Please ask a cancer-related educational question.";

const PSYCHOLOGICAL_SEED_ARTICLES = [
  {
    title: "What is Non-Small Cell Lung Cancer?",
    slug: "what-is-non-small-cell-lung-cancer",
    category: "CANCER",
    summary:
      "A simple explanation of non-small cell lung cancer and why it is different from other lung cancers.",
    content:
      "Non-small cell lung cancer (NSCLC) is the most common type of lung cancer. It includes different subtypes such as adenocarcinoma and squamous cell carcinoma. Doctors use imaging, pathology, and molecular testing to understand each case and select treatment.",
    sources: [
      {
        title: "National Cancer Institute - NSCLC",
        url: "https://www.cancer.gov/types/lung/patient/non-small-cell-lung-treatment-pdq",
      },
      {
        title: "American Cancer Society - Lung Cancer",
        url: "https://www.cancer.org/cancer/types/lung-cancer.html",
      },
    ],
    language: "en",
    readingTimeMinutes: 3,
    isPublished: true,
  },
  {
    title: "What is Treatment Resistance?",
    slug: "what-is-treatment-resistance",
    category: "CANCER",
    summary:
      "Explains why some cancers do not respond to treatment or stop responding after a period of benefit.",
    content:
      "Treatment resistance can be primary (from the beginning) or acquired (after initial response). It can happen through tumor biology changes over time. Doctors monitor for resistance using symptoms, scans, and molecular testing when needed.",
    sources: [
      {
        title: "National Cancer Institute - Drug Resistance",
        url: "https://www.cancer.gov/publications/dictionaries/cancer-terms/def/drug-resistance",
      },
      {
        title: "American Cancer Society - Targeted Therapy",
        url: "https://www.cancer.org/cancer/managing-cancer/treatment-types/targeted-therapy.html",
      },
    ],
    language: "en",
    readingTimeMinutes: 3,
    isPublished: true,
  },
  {
    title: "What is Targeted Therapy?",
    slug: "what-is-targeted-therapy",
    category: "CANCER",
    summary:
      "Explains targeted therapy and why genetic testing can matter in lung cancer.",
    content:
      "Targeted therapy aims at specific biological changes in cancer cells. In lung cancer, tests may check genes such as EGFR, ALK, ROS1, BRAF, KRAS, and others. If a targetable alteration exists, specific drugs may be considered by the oncology team.",
    sources: [
      {
        title: "National Cancer Institute - Targeted Therapies",
        url: "https://www.cancer.gov/about-cancer/treatment/types/targeted-therapies",
      },
      {
        title: "American Cancer Society - Targeted Therapy",
        url: "https://www.cancer.org/cancer/managing-cancer/treatment-types/targeted-therapy.html",
      },
    ],
    language: "en",
    readingTimeMinutes: 3,
    isPublished: true,
  },
  {
    title: "What is Immunotherapy?",
    slug: "what-is-immunotherapy",
    category: "CANCER",
    summary: "Explains how immunotherapy helps the immune system target cancer.",
    content:
      "Immunotherapy helps the immune system recognize and attack cancer. It is not suitable for every patient, and side effects can occur. Oncologists decide if immunotherapy is appropriate based on cancer type, stage, biomarkers, and overall health.",
    sources: [
      {
        title: "National Cancer Institute - Immunotherapy",
        url: "https://www.cancer.gov/about-cancer/treatment/types/immunotherapy",
      },
      {
        title: "American Cancer Society - Immunotherapy",
        url: "https://www.cancer.org/cancer/managing-cancer/treatment-types/immunotherapy.html",
      },
    ],
    language: "en",
    readingTimeMinutes: 3,
    isPublished: true,
  },
  {
    title: "What is Cancer Progression?",
    slug: "what-is-cancer-progression",
    category: "CANCER",
    summary:
      "Explains what doctors mean when they say cancer has progressed.",
    content:
      "Cancer progression means the disease has grown or changed over time based on medical evaluation. Progression can be assessed through scans, symptoms, physical exams, labs, and established clinical criteria such as RECIST in many solid tumors.",
    sources: [
      {
        title: "National Cancer Institute - Progression",
        url: "https://www.cancer.gov/publications/dictionaries/cancer-terms/def/progressive-disease",
      },
    ],
    language: "en",
    readingTimeMinutes: 2,
    isPublished: true,
  },
  {
    title: "Coping with Fear After Diagnosis",
    slug: "coping-with-fear-after-diagnosis",
    category: "WELLBEING",
    summary:
      "Supports patients who feel fear, shock, or uncertainty after a cancer diagnosis.",
    content:
      "Fear after diagnosis is common and understandable. Helpful steps can include breathing exercises, writing questions before appointments, asking for simple explanations, and seeking emotional support from trusted people or professional counselors.",
    sources: [
      {
        title: "American Cancer Society - Emotional Side Effects",
        url: "https://www.cancer.org/cancer/survivorship/coping/emotional-side-effects.html",
      },
    ],
    language: "en",
    readingTimeMinutes: 3,
    isPublished: true,
  },
  {
    title: "Managing Anxiety Before Scans",
    slug: "managing-anxiety-before-scans",
    category: "WELLBEING",
    summary:
      "Helps patients cope with scan-related anxiety while waiting for tests and results.",
    content:
      "Scan anxiety is common. Patients may benefit from short breathing sessions, planning practical routines on scan days, limiting overwhelming online reading, and discussing worries with their care team.",
    sources: [
      {
        title: "NCCN Guidelines for Patients",
        url: "https://www.nccn.org/patientresources/patient-resources/guidelines-for-patients",
      },
    ],
    language: "en",
    readingTimeMinutes: 2,
    isPublished: true,
  },
  {
    title: "Sleep and Cancer Stress",
    slug: "sleep-and-cancer-stress",
    category: "WELLBEING",
    summary: "Simple ways to protect sleep quality during stressful treatment periods.",
    content:
      "Cancer-related stress can affect sleep. Regular sleep timing, reduced screen exposure before bed, and discussing persistent sleep issues with clinicians may help. Avoid starting medication without oncology guidance.",
    sources: [
      {
        title: "National Cancer Institute - Sleep Problems",
        url: "https://www.cancer.gov/about-cancer/coping/survivorship/new-normal/late-effects/sleep-problems-pdq",
      },
    ],
    language: "en",
    readingTimeMinutes: 2,
    isPublished: true,
  },
  {
    title: "Talking to Family About Cancer",
    slug: "talking-to-family-about-cancer",
    category: "WELLBEING",
    summary:
      "Practical guidance for difficult conversations with family and loved ones.",
    content:
      "There is no single correct way to discuss cancer with family. Patients can choose what to share, when to share it, and who should be present. Clear communication can reduce misunderstandings and improve support.",
    sources: [
      {
        title: "American Cancer Society - Talking With Family",
        url: "https://www.cancer.org/cancer/survivorship/coping/how-to-talk-about-cancer.html",
      },
    ],
    language: "en",
    readingTimeMinutes: 2,
    isPublished: true,
  },
  {
    title: "When to Ask for Professional Help",
    slug: "when-to-ask-for-professional-help",
    category: "WELLBEING",
    summary:
      "Explains warning signs that emotional distress needs professional support.",
    content:
      "If sadness, anxiety, panic, sleep disruption, or hopelessness persist and interfere with daily life, patients should seek professional mental-health support. Immediate danger requires emergency services.",
    sources: [
      {
        title: "WHO - Mental Health",
        url: "https://www.who.int/health-topics/mental-health",
      },
    ],
    language: "en",
    readingTimeMinutes: 2,
    isPublished: true,
  },
  {
    title: "What Does Curevoo Do?",
    slug: "what-does-curevoo-do",
    category: "CUREVOO",
    summary:
      "Explains Curevoo in simple terms and clarifies clinical responsibilities.",
    content:
      "Curevoo is a support platform for patients and doctors. It helps organize information and provide education and psychological support features. It does not replace oncology care or final clinical decision-making.",
    sources: [
      {
        title: "Curevoo Product Documentation",
        url: "https://www.curevoo.com",
      },
    ],
    language: "en",
    readingTimeMinutes: 2,
    isPublished: true,
  },
  {
    title: "What is an AI Risk Score?",
    slug: "what-is-an-ai-risk-score",
    category: "CUREVOO",
    summary:
      "Explains that AI scores are support signals and not final treatment decisions.",
    content:
      "An AI risk score is a model output based on available data. It can support clinical review, but models can be wrong or limited by data quality. Doctors remain responsible for diagnosis and treatment planning.",
    sources: [
      {
        title: "National Cancer Institute - Artificial Intelligence",
        url: "https://www.cancer.gov/research/areas/diagnosis/ai",
      },
    ],
    language: "en",
    readingTimeMinutes: 2,
    isPublished: true,
  },
  {
    title: "What Curevoo Cannot Do",
    slug: "what-curevoo-cannot-do",
    category: "CUREVOO",
    summary:
      "Clear boundary statement about diagnosis, treatment, and emergency decisions.",
    content:
      "Curevoo cannot diagnose patients, prescribe medication, choose treatments, or provide emergency intervention. It is a support tool that complements oncology care.",
    sources: [
      {
        title: "NCCN Guidelines for Patients",
        url: "https://www.nccn.org/patientresources/patient-resources/guidelines-for-patients",
      },
    ],
    language: "en",
    readingTimeMinutes: 2,
    isPublished: true,
  },
];

const EDUCATIONAL_SYSTEM_PROMPT = `You are an educational cancer information assistant inside Curevoo.
Your role:
- Provide general educational cancer information.
- Explain concepts in simple patient-friendly language.
- Use reliable medical sources where possible.
- Include sources or source names.
- Encourage the patient to speak with their oncology team for personal decisions.
You must not diagnose, prescribe, choose treatment, or interpret personal medical results.`;

function toTrimmedString(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed || null;
}

function buildPsychologicalExternalPatientId(patientId) {
  return String(patientId).startsWith("CUR-") ? String(patientId) : `CUR-${patientId}`;
}

function mapSexToGraceGender(sex) {
  if (sex === "MALE") return "male";
  if (sex === "FEMALE") return "female";
  if (sex === "OTHER") return "other";
  return undefined;
}

function mapArticleCategoryToDb(category) {
  if (category === "cancer") return "CANCER";
  if (category === "wellbeing") return "WELLBEING";
  if (category === "curevoo") return "CUREVOO";
  return null;
}

function mapArticleCategoryToApi(category) {
  if (category === "CANCER") return "cancer";
  if (category === "WELLBEING") return "wellbeing";
  if (category === "CUREVOO") return "curevoo";
  return null;
}

function mapExerciseTypeToDb(exerciseType) {
  return exerciseType === "box_breathing"
    ? "BOX_BREATHING"
    : "PROGRESSIVE_MUSCLE_RELAXATION";
}

function mapExerciseTypeToApi(exerciseType) {
  return exerciseType === "BOX_BREATHING"
    ? "box_breathing"
    : "progressive_muscle_relaxation";
}

function slugify(value) {
  return String(value || "")
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 300);
}

function getGraceBaseUrl() {
  const base = process.env.PSYCHOLOGICAL_GRACE_BASE_URL || process.env.GRACE_BASE_URL;
  return base ? base.replace(/\/+$/, "") : null;
}

function getGraceInboundApiKey() {
  return (
    process.env.CUREVOO_INBOUND_API_KEY ||
    process.env.GRACE_INBOUND_API_KEY ||
    process.env.GRACE_API_KEY ||
    null
  );
}

function assertGraceConfig() {
  if (!getGraceBaseUrl() || !getGraceInboundApiKey()) {
    throw new AppError(
      "Psychological support service is temporarily unavailable.",
      503,
      "PSYCHOLOGICAL_GRACE_UNAVAILABLE",
    );
  }
}

async function requestGrace(path, body) {
  assertGraceConfig();
  const url = `${getGraceBaseUrl()}${path}`;

  let response;
  try {
    response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${getGraceInboundApiKey()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });
  } catch {
    throw new AppError(
      "Psychological support service is temporarily unavailable.",
      503,
      "PSYCHOLOGICAL_GRACE_UNAVAILABLE",
    );
  }

  let payload = null;
  try {
    payload = await response.json();
  } catch {
    payload = null;
  }

  return { status: response.status, ok: response.ok, payload };
}

function normalizeGraceErrorMessage(payload) {
  return (
    toTrimmedString(payload?.message) ||
    toTrimmedString(payload?.error) ||
    "Psychological support service request failed."
  );
}

function extractUrls(text) {
  if (!text) return [];
  const matches = String(text).match(/https?:\/\/[^\s)]+/gi) || [];
  const unique = [];
  const seen = new Set();

  for (const url of matches) {
    if (seen.has(url)) continue;
    seen.add(url);
    unique.push(url);
  }

  return unique;
}

function toSourceObjects(urls) {
  return urls.map((url) => {
    let title = "Trusted source";
    try {
      title = new URL(url).hostname.replace(/^www\./, "");
    } catch {
      // Keep fallback title.
    }
    return { title, url };
  });
}

function isCrisisQuestion(question) {
  const normalized = question.toLowerCase();
  const crisisKeywords = [
    "hurt myself",
    "kill myself",
    "suicide",
    "end my life",
    "can't stay safe",
    "cannot stay safe",
    "self harm",
    "self-harm",
  ];
  return crisisKeywords.some((keyword) => normalized.includes(keyword));
}

function isBlockedMedicalAdviceQuestion(question) {
  const normalized = question.toLowerCase();
  const blockedKeywords = [
    "stop my medication",
    "change my medication",
    "what dose should i take",
    "which treatment should i choose",
    "is my doctor wrong",
    "do i have cancer",
    "interpret my scan",
    "interpret my lab",
    "interpret my pathology",
    "interpret my genomic",
    "upload my scan",
  ];
  return blockedKeywords.some((keyword) => normalized.includes(keyword));
}

function isCancerRelatedQuestion(question) {
  const normalized = question.toLowerCase();
  const cancerKeywords = [
    "cancer",
    "oncology",
    "tumor",
    "tumour",
    "nsclc",
    "egfr",
    "immunotherapy",
    "chemotherapy",
    "targeted therapy",
    "metastatic",
    "progression",
    "scanxiety",
  ];
  return cancerKeywords.some((keyword) => normalized.includes(keyword));
}

function pickFallbackArticleAnswer(question, articles) {
  const terms = String(question || "")
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter(Boolean);

  let bestArticle = null;
  let bestScore = 0;

  for (const article of articles) {
    const haystack = `${article.title} ${article.summary} ${article.content}`.toLowerCase();
    let score = 0;
    for (const term of terms) {
      if (term.length < 3) continue;
      if (haystack.includes(term)) score += 1;
    }
    if (score > bestScore) {
      bestScore = score;
      bestArticle = article;
    }
  }

  if (!bestArticle) {
    return {
      answer:
        "I can help with general educational cancer information. Try asking about NSCLC, treatment resistance, EGFR targeted therapy, immunotherapy, or coping with anxiety.",
      sources: [
        {
          title: "National Cancer Institute",
          url: "https://www.cancer.gov/",
        },
      ],
    };
  }

  return {
    answer: `${bestArticle.summary} ${bestArticle.content}`,
    sources: Array.isArray(bestArticle.sources) ? bestArticle.sources : [],
  };
}

function getDeepSeekConfig() {
  return {
    baseUrl: (process.env.DEEPSEEK_BASE_URL || "https://api.deepseek.com").replace(
      /\/+$/,
      "",
    ),
    apiKey: process.env.DEEPSEEK_API_KEY || null,
    model: process.env.DEEPSEEK_MODEL || "deepseek-chat",
  };
}

async function askDeepSeekEducational(question) {
  const config = getDeepSeekConfig();
  if (!config.apiKey) return null;

  let response;
  try {
    response = await fetch(`${config.baseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${config.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: config.model,
        temperature: 0.2,
        max_tokens: 700,
        messages: [
          { role: "system", content: EDUCATIONAL_SYSTEM_PROMPT },
          { role: "user", content: question },
        ],
      }),
    });
  } catch {
    return null;
  }

  if (!response.ok) return null;

  let payload = null;
  try {
    payload = await response.json();
  } catch {
    payload = null;
  }

  const answer = toTrimmedString(payload?.choices?.[0]?.message?.content);
  if (!answer) return null;

  const urls = extractUrls(answer);
  return {
    answer,
    sources: urls.length ? toSourceObjects(urls) : [],
  };
}

function formatArticleForApi(article) {
  return {
    id: article.id,
    title: article.title,
    slug: article.slug,
    category: mapArticleCategoryToApi(article.category),
    summary: article.summary,
    content: article.content,
    sources: Array.isArray(article.sources) ? article.sources : [],
    language: article.language,
    reading_time_minutes: article.readingTimeMinutes,
    created_at: article.createdAt,
    updated_at: article.updatedAt,
  };
}

function formatArticleMetadataForAdminApi(article) {
  return {
    id: article.id,
    title: article.title,
    slug: article.slug,
    category: mapArticleCategoryToApi(article.category),
    summary: article.summary,
    sources: Array.isArray(article.sources) ? article.sources : [],
    language: article.language,
    reading_time_minutes: article.readingTimeMinutes,
    is_published: article.isPublished,
    created_at: article.createdAt,
    updated_at: article.updatedAt,
  };
}

async function ensureKnowledgeArticlesSeeded() {
  const total = await repo.countKnowledgeArticles();
  if (total > 0) return;
  await repo.createManyKnowledgeArticles(PSYCHOLOGICAL_SEED_ARTICLES);
}

async function requirePsychologicalPatient(patientUserId) {
  const patient = await repo.findPsychologicalPatientById(patientUserId);
  if (!patient || patient.role !== "PATIENT") {
    throw new AppError("Patient not found", 404, "PATIENT_NOT_FOUND");
  }
  return patient;
}

async function linkPatientInGrace(patientUserId) {
  const patient = await requirePsychologicalPatient(patientUserId);
  const existing = await repo.findPsychologicalChatSessionByPatientId(patientUserId);

  if (existing?.gracePatientId && existing?.redirectUrl) {
    return existing;
  }

  const graceRequestBody = {
    curevoo_patient_id: buildPsychologicalExternalPatientId(patient.id),
    full_name:
      toTrimmedString(patient.patientProfile?.fullName) ||
      toTrimmedString(patient.name) ||
      "Curevoo Patient",
    gender: mapSexToGraceGender(patient.patientProfile?.sex),
    contact: patient.email ? { email: patient.email } : undefined,
    preferred_language: "en",
    source: "curevoo_psychological_support",
  };

  const graceResponse = await requestGrace(
    "/api/v1/integration/curevoo/patient",
    graceRequestBody,
  );
  if (!graceResponse.ok && graceResponse.status !== 409) {
    throw new AppError(
      normalizeGraceErrorMessage(graceResponse.payload),
      graceResponse.status >= 500 ? 503 : 502,
      "PSYCHOLOGICAL_GRACE_LINK_FAILED",
    );
  }

  const gracePatientId =
    toTrimmedString(graceResponse.payload?.grace_patient_id) || existing?.gracePatientId || null;
  const redirectUrl =
    toTrimmedString(graceResponse.payload?.redirect_url) || existing?.redirectUrl || null;

  return repo.upsertPsychologicalChatSessionByPatientId({
    patientId: patientUserId,
    gracePatientId,
    redirectUrl,
    sessionId: existing?.sessionId || null,
  });
}

// Executes the "generate grace link" workflow for this module.
async function createGraceRedirectLink(patientUserId) {
  const session = await linkPatientInGrace(patientUserId);
  if (!session.redirectUrl) {
    throw new AppError(
      "Psychological support service did not provide redirect URL.",
      502,
      "PSYCHOLOGICAL_REDIRECT_URL_MISSING",
    );
  }

  return {
    redirect_url: session.redirectUrl,
  };
}

// Executes the "get psychological chat session metadata" workflow for this module.
async function getPsychologicalChatSession(patientUserId) {
  await requirePsychologicalPatient(patientUserId);
  const session = await repo.findPsychologicalChatSessionByPatientId(patientUserId);

  return {
    session_id: session?.sessionId || null,
    grace_patient_id: session?.gracePatientId || null,
    redirect_url: session?.redirectUrl || null,
    has_active_session: !!session?.sessionId,
    updated_at: session?.updatedAt || null,
  };
}

// Executes the "send psychological chat message" workflow for this module.
async function sendPsychologicalChatMessage(patientUserId, data) {
  const patient = await requirePsychologicalPatient(patientUserId);
  const linked = await linkPatientInGrace(patientUserId);
  const activeSessionId = toTrimmedString(data.session_id) || linked.sessionId || null;

  const graceRequestBody = {
    curevoo_patient_id: buildPsychologicalExternalPatientId(patient.id),
    message: data.message,
    ...(activeSessionId ? { session_id: activeSessionId } : {}),
  };

  const graceResponse = await requestGrace(
    "/api/v1/integration/curevoo/liora/chat",
    graceRequestBody,
  );
  if (!graceResponse.ok) {
    throw new AppError(
      normalizeGraceErrorMessage(graceResponse.payload),
      graceResponse.status >= 500 ? 503 : 502,
      "PSYCHOLOGICAL_CHAT_FAILED",
    );
  }

  const reply = toTrimmedString(graceResponse.payload?.reply);
  const sessionId =
    toTrimmedString(graceResponse.payload?.session_id) || activeSessionId || null;
  if (!reply || !sessionId) {
    throw new AppError(
      "Psychological support response is invalid.",
      502,
      "PSYCHOLOGICAL_CHAT_INVALID_RESPONSE",
    );
  }

  const savedSession = await repo.upsertPsychologicalChatSessionByPatientId({
    patientId: patientUserId,
    gracePatientId: linked.gracePatientId || null,
    redirectUrl: linked.redirectUrl || null,
    sessionId,
  });

  await Promise.all([
    repo.createPsychologicalChatMessage({
      patientId: patientUserId,
      chatSessionId: savedSession.id,
      sessionId,
      sender: "PATIENT",
      message: data.message,
    }),
    repo.createPsychologicalChatMessage({
      patientId: patientUserId,
      chatSessionId: savedSession.id,
      sessionId,
      sender: "LIORA",
      message: reply,
    }),
  ]);

  return {
    reply,
    session_id: sessionId,
  };
}

// Executes the "store exercise completion" workflow for this module.
async function completePsychologicalExercise(patientUserId, data) {
  await requirePsychologicalPatient(patientUserId);

  const created = await repo.createPsychologicalExerciseLog({
    patientId: patientUserId,
    exerciseType: mapExerciseTypeToDb(data.exercise_type),
    durationMinutes: data.duration_minutes,
  });

  return {
    saved: true,
    exercise_log: {
      id: created.id,
      exercise_type: mapExerciseTypeToApi(created.exerciseType),
      duration_minutes: created.durationMinutes,
      completed_at: created.completedAt,
    },
  };
}

// Executes the "list published psychological knowledge articles" workflow.
async function listPsychologicalArticles(query) {
  await ensureKnowledgeArticlesSeeded();

  const category = query?.category ? mapArticleCategoryToDb(query.category) : null;
  const language = toTrimmedString(query?.language) || undefined;

  const items = await repo.listPublishedKnowledgeArticles({
    category,
    language,
  });

  return {
    items: items.map(formatArticleForApi),
  };
}

// Executes the "list all knowledge articles for admin" workflow.
async function listKnowledgeArticlesForAdmin(query) {
  await ensureKnowledgeArticlesSeeded();

  const category = query?.category ? mapArticleCategoryToDb(query.category) : null;
  const language = toTrimmedString(query?.language) || undefined;

  const items = await repo.listKnowledgeArticlesForAdmin({
    category,
    language,
  });

  return {
    items: items.map(formatArticleForApi),
  };
}

// Executes the "get published psychological knowledge article details" workflow.
async function getPsychologicalArticleById(articleId) {
  await ensureKnowledgeArticlesSeeded();
  const article = await repo.findPublishedKnowledgeArticleById(articleId);
  if (!article) {
    throw new AppError("Article not found", 404, "ARTICLE_NOT_FOUND");
  }
  return formatArticleForApi(article);
}

// Executes the "get knowledge article by id for admin" workflow.
async function getKnowledgeArticleByIdForAdmin(articleId) {
  await ensureKnowledgeArticlesSeeded();
  const article = await repo.findKnowledgeArticleByIdForAdmin(articleId);
  if (!article) {
    throw new AppError("Article not found", 404, "ARTICLE_NOT_FOUND");
  }
  return formatArticleForApi(article);
}

// Executes the "get knowledge article metadata by id for admin" workflow.
async function getKnowledgeArticleMetadataByIdForAdmin(articleId) {
  await ensureKnowledgeArticlesSeeded();
  const article = await repo.findKnowledgeArticleByIdForAdmin(articleId);
  if (!article) {
    throw new AppError("Article not found", 404, "ARTICLE_NOT_FOUND");
  }
  return formatArticleMetadataForAdminApi(article);
}

// Executes the "educational cancer search" workflow for this module.
async function searchEducationalCancerInfo(patientUserId, data) {
  await requirePsychologicalPatient(patientUserId);
  await ensureKnowledgeArticlesSeeded();

  const question = data.question.trim();
  const normalizedQuestion = question.toLowerCase();

  if (isCrisisQuestion(normalizedQuestion)) {
    await repo.createEducationalSearchLog({
      patientId: patientUserId,
      question,
      answerSummary: CRISIS_REDIRECT_MESSAGE.slice(0, 500),
      safetyStatus: "CRISIS",
    });

    return {
      answer: CRISIS_REDIRECT_MESSAGE,
      sources: [],
      disclaimer: EDUCATIONAL_DISCLAIMER,
      safety_status: "crisis",
    };
  }

  if (!isCancerRelatedQuestion(normalizedQuestion)) {
    await repo.createEducationalSearchLog({
      patientId: patientUserId,
      question,
      answerSummary: NON_CANCER_SCOPE_MESSAGE.slice(0, 500),
      safetyStatus: "BLOCKED",
    });

    return {
      answer: NON_CANCER_SCOPE_MESSAGE,
      sources: [],
      disclaimer: EDUCATIONAL_DISCLAIMER,
      safety_status: "blocked",
    };
  }

  if (isBlockedMedicalAdviceQuestion(normalizedQuestion)) {
    await repo.createEducationalSearchLog({
      patientId: patientUserId,
      question,
      answerSummary: SAFE_REFUSAL_MESSAGE.slice(0, 500),
      safetyStatus: "BLOCKED",
    });

    return {
      answer: SAFE_REFUSAL_MESSAGE,
      sources: [],
      disclaimer: EDUCATIONAL_DISCLAIMER,
      safety_status: "blocked",
    };
  }

  let generated = await askDeepSeekEducational(question);
  if (!generated) {
    const allArticles = await repo.listPublishedKnowledgeArticles({});
    generated = pickFallbackArticleAnswer(question, allArticles.map(formatArticleForApi));
  }

  const sources =
    Array.isArray(generated.sources) && generated.sources.length
      ? generated.sources
      : [
          {
            title: "National Cancer Institute",
            url: "https://www.cancer.gov/",
          },
        ];

  await repo.createEducationalSearchLog({
    patientId: patientUserId,
    question,
    answerSummary: String(generated.answer).slice(0, 500),
    safetyStatus: "ALLOWED",
  });

  return {
    answer: generated.answer,
    sources,
    disclaimer: EDUCATIONAL_DISCLAIMER,
    safety_status: "allowed",
  };
}

// Executes the "create knowledge article" admin workflow for this module.
async function createKnowledgeArticle(data) {
  const created = await repo.createKnowledgeArticle({
    title: data.title,
    slug: data.slug ? slugify(data.slug) : slugify(data.title),
    category: mapArticleCategoryToDb(data.category),
    summary: data.summary,
    content: data.content,
    sources: data.sources ?? [],
    language: data.language ?? "en",
    readingTimeMinutes: data.reading_time_minutes ?? null,
    isPublished: data.is_published ?? true,
  });
  return formatArticleForApi(created);
}

// Executes the "update knowledge article" admin workflow for this module.
async function updateKnowledgeArticle(articleId, data) {
  const existing = await repo.findKnowledgeArticleByIdForAdmin(articleId);
  if (!existing) {
    throw new AppError("Article not found", 404, "ARTICLE_NOT_FOUND");
  }

  const updated = await repo.updateKnowledgeArticleById(articleId, {
    title: data.title ?? undefined,
    slug:
      data.slug !== undefined
        ? slugify(data.slug)
        : data.title !== undefined
          ? slugify(data.title)
          : undefined,
    category: data.category ? mapArticleCategoryToDb(data.category) : undefined,
    summary: data.summary ?? undefined,
    content: data.content ?? undefined,
    sources: data.sources ?? undefined,
    language: data.language ?? undefined,
    readingTimeMinutes: data.reading_time_minutes ?? undefined,
    isPublished: data.is_published ?? undefined,
  });

  return formatArticleForApi(updated);
}

// Executes the "delete knowledge article" admin workflow for this module.
async function deleteKnowledgeArticle(articleId) {
  const existing = await repo.findKnowledgeArticleByIdForAdmin(articleId);
  if (!existing) {
    throw new AppError("Article not found", 404, "ARTICLE_NOT_FOUND");
  }

  const deleted = await repo.deleteKnowledgeArticleById(articleId);
  return {
    deleted: true,
    article: deleted,
  };
}

module.exports = {
  completePsychologicalExercise,
  createGraceRedirectLink,
  createKnowledgeArticle,
  deleteKnowledgeArticle,
  getKnowledgeArticleByIdForAdmin,
  getKnowledgeArticleMetadataByIdForAdmin,
  getPsychologicalArticleById,
  getPsychologicalChatSession,
  listKnowledgeArticlesForAdmin,
  listPsychologicalArticles,
  searchEducationalCancerInfo,
  sendPsychologicalChatMessage,
  updateKnowledgeArticle,
};
