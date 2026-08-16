// Defines request validation schemas for NSCLC prediction endpoints.
const { z } = require("zod");

const overrideValueSchema = z.union([z.string().trim().min(1), z.number(), z.boolean(), z.null()]);

const predictNsclcSchema = z.object({
  patientId: z.string().trim().min(1),
  includeLlmExplanation: z.boolean().optional(),
  overrides: z.record(overrideValueSchema).optional(),
});

const nsclcPatientIdParamSchema = z.object({
  patientId: z.string().trim().min(1),
});

module.exports = {
  predictNsclcSchema,
  nsclcPatientIdParamSchema,
};
