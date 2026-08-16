// Defines request validation schemas for genomic target prioritization endpoints.
const { z } = require("zod");

const MIN_TOP_N = 1;
const MAX_TOP_N = 100;
const DEFAULT_TOP_N = 20;

const analyzeGenomicTargetsSchema = z.object({
  topN: z.coerce.number().int().min(MIN_TOP_N).max(MAX_TOP_N).default(DEFAULT_TOP_N),
});

const genomicAnalysisRunIdParamSchema = z.object({
  runId: z
    .string()
    .trim()
    .min(1)
    .max(64)
    .regex(/^[a-zA-Z0-9]+$/, "Run id must be alphanumeric"),
});

module.exports = {
  analyzeGenomicTargetsSchema,
  genomicAnalysisRunIdParamSchema,
};
