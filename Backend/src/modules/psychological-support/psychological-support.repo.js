// Handles psychological support persistence and lookups.
const prisma = require("../../prisma/client");

// Loads the patient user and profile data required for Grace and psychological flows.
async function findPsychologicalPatientById(patientUserId) {
  return prisma.user.findUnique({
    where: { id: patientUserId },
    select: {
      id: true,
      role: true,
      email: true,
      name: true,
      patientProfile: {
        select: {
          fullName: true,
          sex: true,
          age: true,
        },
      },
    },
  });
}

// Loads the latest chat session metadata for one patient.
async function findPsychologicalChatSessionByPatientId(patientUserId) {
  return prisma.psychologicalChatSession.findUnique({
    where: { patientId: patientUserId },
    select: {
      id: true,
      patientId: true,
      gracePatientId: true,
      sessionId: true,
      redirectUrl: true,
      createdAt: true,
      updatedAt: true,
    },
  });
}

// Upserts per-patient chat session metadata so Grace and Liora session continuity is preserved.
async function upsertPsychologicalChatSessionByPatientId({
  patientId,
  gracePatientId,
  sessionId,
  redirectUrl,
}) {
  return prisma.psychologicalChatSession.upsert({
    where: { patientId },
    create: {
      patientId,
      gracePatientId: gracePatientId ?? null,
      sessionId: sessionId ?? null,
      redirectUrl: redirectUrl ?? null,
    },
    update: {
      gracePatientId: gracePatientId ?? undefined,
      sessionId: sessionId ?? undefined,
      redirectUrl: redirectUrl ?? undefined,
    },
    select: {
      id: true,
      patientId: true,
      gracePatientId: true,
      sessionId: true,
      redirectUrl: true,
      createdAt: true,
      updatedAt: true,
    },
  });
}

// Stores one chat message for optional audit/history display.
async function createPsychologicalChatMessage({
  patientId,
  chatSessionId,
  sessionId,
  sender,
  message,
}) {
  return prisma.psychologicalChatMessage.create({
    data: {
      patientId,
      chatSessionId: chatSessionId ?? null,
      sessionId: sessionId ?? null,
      sender,
      message,
    },
    select: {
      id: true,
      patientId: true,
      sessionId: true,
      sender: true,
      message: true,
      createdAt: true,
    },
  });
}

// Stores completion metadata for one relaxation exercise.
async function createPsychologicalExerciseLog({
  patientId,
  exerciseType,
  durationMinutes,
}) {
  return prisma.psychologicalExerciseLog.create({
    data: {
      patientId,
      exerciseType,
      durationMinutes: durationMinutes ?? null,
    },
    select: {
      id: true,
      patientId: true,
      exerciseType: true,
      durationMinutes: true,
      completedAt: true,
    },
  });
}

// Returns published knowledge articles for patient-facing views.
async function listPublishedKnowledgeArticles({ category, language }) {
  return prisma.knowledgeArticle.findMany({
    where: {
      isPublished: true,
      category: category ?? undefined,
      language: language ?? undefined,
    },
    orderBy: [{ createdAt: "desc" }],
    select: {
      id: true,
      title: true,
      slug: true,
      category: true,
      summary: true,
      content: true,
      sources: true,
      language: true,
      readingTimeMinutes: true,
      createdAt: true,
      updatedAt: true,
    },
  });
}

// Returns all knowledge articles for admin-facing views.
async function listKnowledgeArticlesForAdmin({ category, language }) {
  return prisma.knowledgeArticle.findMany({
    where: {
      category: category ?? undefined,
      language: language ?? undefined,
    },
    orderBy: [{ createdAt: "desc" }],
    select: {
      id: true,
      title: true,
      slug: true,
      category: true,
      summary: true,
      content: true,
      sources: true,
      language: true,
      readingTimeMinutes: true,
      isPublished: true,
      createdAt: true,
      updatedAt: true,
    },
  });
}

// Returns one published knowledge article by id.
async function findPublishedKnowledgeArticleById(id) {
  return prisma.knowledgeArticle.findFirst({
    where: {
      id,
      isPublished: true,
    },
    select: {
      id: true,
      title: true,
      slug: true,
      category: true,
      summary: true,
      content: true,
      sources: true,
      language: true,
      readingTimeMinutes: true,
      createdAt: true,
      updatedAt: true,
    },
  });
}

// Returns one knowledge article regardless of publish state for admin workflows.
async function findKnowledgeArticleByIdForAdmin(id) {
  return prisma.knowledgeArticle.findUnique({
    where: { id },
    select: {
      id: true,
      title: true,
      slug: true,
      category: true,
      summary: true,
      content: true,
      sources: true,
      language: true,
      readingTimeMinutes: true,
      isPublished: true,
      createdAt: true,
      updatedAt: true,
    },
  });
}

// Inserts default article rows when the table is empty.
async function createManyKnowledgeArticles(records) {
  return prisma.knowledgeArticle.createMany({
    data: records,
    skipDuplicates: true,
  });
}

// Counts knowledge articles for bootstrap checks.
async function countKnowledgeArticles() {
  return prisma.knowledgeArticle.count();
}

// Creates one knowledge article in admin flow.
async function createKnowledgeArticle(data) {
  return prisma.knowledgeArticle.create({
    data,
    select: {
      id: true,
      title: true,
      slug: true,
      category: true,
      summary: true,
      content: true,
      sources: true,
      language: true,
      readingTimeMinutes: true,
      isPublished: true,
      createdAt: true,
      updatedAt: true,
    },
  });
}

// Updates one knowledge article in admin flow.
async function updateKnowledgeArticleById(id, data) {
  return prisma.knowledgeArticle.update({
    where: { id },
    data,
    select: {
      id: true,
      title: true,
      slug: true,
      category: true,
      summary: true,
      content: true,
      sources: true,
      language: true,
      readingTimeMinutes: true,
      isPublished: true,
      createdAt: true,
      updatedAt: true,
    },
  });
}

// Deletes one knowledge article in admin flow.
async function deleteKnowledgeArticleById(id) {
  return prisma.knowledgeArticle.delete({
    where: { id },
    select: {
      id: true,
      title: true,
      slug: true,
    },
  });
}

// Stores educational search activity for audit and monitoring.
async function createEducationalSearchLog({
  patientId,
  question,
  answerSummary,
  safetyStatus,
}) {
  return prisma.educationalSearchLog.create({
    data: {
      patientId,
      question,
      answerSummary: answerSummary ?? null,
      safetyStatus,
    },
    select: {
      id: true,
      patientId: true,
      question: true,
      answerSummary: true,
      safetyStatus: true,
      createdAt: true,
    },
  });
}

module.exports = {
  countKnowledgeArticles,
  createEducationalSearchLog,
  createKnowledgeArticle,
  createManyKnowledgeArticles,
  createPsychologicalChatMessage,
  createPsychologicalExerciseLog,
  deleteKnowledgeArticleById,
  findKnowledgeArticleByIdForAdmin,
  findPsychologicalChatSessionByPatientId,
  findPsychologicalPatientById,
  findPublishedKnowledgeArticleById,
  listKnowledgeArticlesForAdmin,
  listPublishedKnowledgeArticles,
  updateKnowledgeArticleById,
  upsertPsychologicalChatSessionByPatientId,
};
