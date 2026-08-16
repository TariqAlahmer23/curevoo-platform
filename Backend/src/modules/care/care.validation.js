// Defines request validation schemas for care endpoints.
const { z } = require("zod");
const {
  parseOptionalJsonObject,
  parseOptionalJsonValue,
} = require("../../common/utils/inputParsers");

const jsonValueSchema = z.lazy(() =>
  z.union([
    z.string(),
    z.number(),
    z.boolean(),
    z.null(),
    z.array(jsonValueSchema),
    z.record(jsonValueSchema),
  ]),
);

const jsonObjectSchema = z.record(jsonValueSchema);
const parsedJsonObjectSchema = z.preprocess(
  parseOptionalJsonObject,
  jsonObjectSchema,
);
const parsedJsonValueSchema = z.preprocess(
  parseOptionalJsonValue,
  jsonValueSchema,
);

const createTreatmentPlanBodySchema = z.object({
  treatmentPlan: parsedJsonObjectSchema,
  symptomsLog: parsedJsonValueSchema.optional(),
});

const createTreatmentPlanSchema = createTreatmentPlanBodySchema
  .extend({
    patientUserId: z.string().min(1).optional(),
    patientId: z.string().min(1).optional(),
  })
  .superRefine((data, ctx) => {
    if (data.patientUserId || data.patientId) return;

    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["patientId"],
      message: "patientId is required",
    });
  })
  .transform(({ patientId, patientUserId, ...data }) => ({
    ...data,
    patientId: patientId ?? patientUserId,
  }));

const createTreatmentPlanForDoctorPatientSchema = createTreatmentPlanBodySchema;

const updateTreatmentPlanSchema = z
  .object({
    treatmentPlan: parsedJsonObjectSchema.optional(),
    symptomsLog: parsedJsonValueSchema.optional(),
  })
  .refine(
    (data) => data.treatmentPlan !== undefined || data.symptomsLog !== undefined,
    {
      message: "At least one field is required",
      path: ["treatmentPlan"],
    },
  );

const createHistoryRecordSchema = z.object({
  record: parsedJsonObjectSchema,
});

const requestHistoryRecordUpdateSchema = z.object({
  doctorUserId: z.string().min(1),
  record: parsedJsonObjectSchema,
});

const updateHistoryRecordByDoctorSchema = z.object({
  record: parsedJsonObjectSchema,
});

const respondHistoryUpdateRequestSchema = z.object({
  action: z.enum(["APPROVE", "REJECT"]),
});

module.exports = {
  createTreatmentPlanSchema,
  createTreatmentPlanForDoctorPatientSchema,
  updateTreatmentPlanSchema,
  createHistoryRecordSchema,
  requestHistoryRecordUpdateSchema,
  updateHistoryRecordByDoctorSchema,
  respondHistoryUpdateRequestSchema,
};
