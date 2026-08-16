// Defines request validation schemas for cancer resistance AI endpoints.
const { z } = require("zod");

const startCancerResistanceSchema = z.object({
  sessionId: z.string().trim().min(1).max(100).optional(),
  entryIntent: z
    .enum([
      "/start_cancer_resistance",
      "/start_resistance_assessment",
    ])
    .optional(),
});

const sendCancerResistanceMessageSchema = z.object({
  sessionId: z.string().trim().min(1).max(100).optional(),
  message: z.string().trim().min(1),
});

module.exports = {
  startCancerResistanceSchema,
  sendCancerResistanceMessageSchema,
};
