// Defines request validation schemas for admin doctor/patient management endpoints.
const { z } = require("zod");
const {
  createAccountSchema,
} = require("../registration/registration.validation");
const {
  normalizeOptionalString,
  parseOptionalInteger,
  parseOptionalJsonObject,
  parseStringArray,
} = require("../../common/utils/inputParsers");

const requiredDoctorCreateSchema = createAccountSchema.superRefine((data, ctx) => {
  if (!data.fullName) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["fullName"],
      message: "fullName is required for doctor creation",
    });
  }
});

const requiredPatientCreateSchema = createAccountSchema.superRefine((data, ctx) => {
  if (!data.fullName) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["fullName"],
      message: "fullName is required for patient creation",
    });
  }
});

const updateDoctorByAdminSchema = z
  .object({
    email: z.string().email().optional(),
    password: z.string().min(8).optional(),
    fullName: z.preprocess(
      normalizeOptionalString,
      z.string().min(2).max(100).optional(),
    ),
    phoneNumber: z.preprocess(
      normalizeOptionalString,
      z.string().min(5).max(30).optional(),
    ),
    age: z.preprocess(
      parseOptionalInteger,
      z.number().int().min(18).max(120).optional(),
    ),
    specialization: z.preprocess(
      normalizeOptionalString,
      z.string().min(2).max(100).optional(),
    ),
    workingAt: z.preprocess(
      normalizeOptionalString,
      z.string().min(2).max(255).optional(),
    ),
    experience: z.preprocess(
      parseOptionalInteger,
      z.number().int().min(0).max(70).optional(),
    ),
    location: z.preprocess(
      normalizeOptionalString,
      z.string().min(2).max(255).optional(),
    ),
    languages: z.preprocess(
      parseStringArray,
      z.array(z.string().min(2).max(50)).min(1).max(20).optional(),
    ),
    photoUrl: z.preprocess(
      normalizeOptionalString,
      z.string().url().max(500).optional(),
    ),
    qualifications: z.preprocess(
      normalizeOptionalString,
      z.string().max(500).optional(),
    ),
    bio: z.preprocess(
      normalizeOptionalString,
      z.string().max(1000).optional(),
    ),
    consultationFee: z.preprocess(
      (value) => {
        if (value === undefined || value === null || value === "") return undefined;
        if (typeof value === "number") return value;
        if (typeof value !== "string") return value;
        const parsed = Number(value.trim());
        return Number.isFinite(parsed) ? parsed : value;
      },
      z.number().positive().optional(),
    ),
    isActive: z.preprocess(
      (value) => {
        if (value === undefined) return undefined;
        if (typeof value === "boolean") return value;
        if (typeof value === "string") {
          const normalized = value.trim().toLowerCase();
          if (normalized === "true") return true;
          if (normalized === "false") return false;
        }
        return value;
      },
      z.boolean().optional(),
    ),
  })
  .refine((data) => Object.values(data).some((value) => value !== undefined), {
    message: "At least one field is required",
    path: ["email"],
  });

const updatePatientByAdminSchema = z
  .object({
    email: z.string().email().optional(),
    password: z.string().min(8).optional(),
    fullName: z.preprocess(
      normalizeOptionalString,
      z.string().min(2).max(100).optional(),
    ),
    phoneNumber: z.preprocess(
      normalizeOptionalString,
      z.string().min(5).max(30).optional(),
    ),
    age: z.preprocess(
      parseOptionalInteger,
      z.number().int().min(0).max(120).optional(),
    ),
    sex: z.enum(["MALE", "FEMALE", "OTHER"]).optional(),
    address: z.preprocess(
      normalizeOptionalString,
      z.string().min(2).max(255).optional(),
    ),
    medicalHistory: z.preprocess(
      normalizeOptionalString,
      z.string().max(5000).optional(),
    ),
    riskFactors: z.preprocess(
      parseOptionalJsonObject,
      z.record(z.any()).optional(),
    ),
  })
  .refine((data) => Object.values(data).some((value) => value !== undefined), {
    message: "At least one field is required",
    path: ["email"],
  });

module.exports = {
  requiredDoctorCreateSchema,
  requiredPatientCreateSchema,
  updateDoctorByAdminSchema,
  updatePatientByAdminSchema,
};
