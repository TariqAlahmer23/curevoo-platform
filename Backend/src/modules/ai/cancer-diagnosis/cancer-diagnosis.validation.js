// Defines request validation schemas for cancer diagnosis AI endpoints.
const { z } = require("zod");

const startCancerDiagnosisSchema = z.object({
  sessionId: z.string().trim().min(1).max(100).optional(),
  entryIntent: z
    .enum([
      "/start",
      "/start_questions_only",
      "/start_image_only",
      "/start_questions_and_image",
      "/select_language_ar",
      "/select_language_en",
    ])
    .optional(),
});

const sendCancerDiagnosisMessageSchema = z.object({
  sessionId: z.string().trim().min(1).max(100).optional(),
  message: z.string().trim().min(1),
});

const submitCancerDiagnosisImageSchema = z.object({
  sessionId: z.string().trim().min(1).max(100).optional(),
});

module.exports = {
  startCancerDiagnosisSchema,
  sendCancerDiagnosisMessageSchema,
  submitCancerDiagnosisImageSchema,
};
