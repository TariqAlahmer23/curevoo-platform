// Defines request validation schemas for doctor profile and settings updates.
const { z } = require("zod");
const {
  normalizeOptionalString,
  parseOptionalInteger,
  parseOptionalJsonObject,
  parseStringArray,
} = require("../../common/utils/inputParsers");

const updateDoctorProfileSchema = z.object({
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
  languages: z.preprocess(
    parseStringArray,
    z.array(z.string().min(2).max(50)).min(1).max(20).optional(),
  ),
  location: z.preprocess(
    normalizeOptionalString,
    z.string().min(2).max(255).optional(),
  ),
  qualifications: z.preprocess(
    normalizeOptionalString,
    z.string().max(500).optional(),
  ),
  experience: z.preprocess(
    parseOptionalInteger,
    z.number().int().min(0).max(70).optional(),
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
});

const updateDoctorSettingsSchema = z.object({
  language: z.enum(["ar", "en"]).optional(),
  notificationsEnabled: z.boolean().optional(),
});

const optionalPatientName = z.preprocess(
  normalizeOptionalString,
  z.string().min(2).max(100).optional(),
);

const optionalPatientPhoneNumber = z.preprocess(
  normalizeOptionalString,
  z.string().min(5).max(30).optional(),
);

const createDoctorPatientSchema = z
  .object({
    name: optionalPatientName,
    fullName: optionalPatientName,
    phoneNumber: optionalPatientPhoneNumber,
    age: z.preprocess(
      parseOptionalInteger,
      z.number().int().min(0).max(120),
    ),
    sex: z.enum(["MALE", "FEMALE", "OTHER"]),
    medicalHistory: z.preprocess(
      normalizeOptionalString,
      z.string().max(5000).optional(),
    ),
    riskFactors: z.preprocess(
      parseOptionalJsonObject,
      z.record(z.any()).optional(),
    ),
  })
  .superRefine((data, ctx) => {
    if (data.name || data.fullName) return;

    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["name"],
      message: "name is required",
    });
  })
  .transform(({ name, fullName, ...data }) => ({
    ...data,
    fullName: fullName ?? name,
  }));

const updateDoctorCreatedPatientSchema = z
  .object({
    name: optionalPatientName,
    fullName: optionalPatientName,
    phoneNumber: optionalPatientPhoneNumber,
    age: z.preprocess(
      parseOptionalInteger,
      z.number().int().min(0).max(120).optional(),
    ),
    sex: z.enum(["MALE", "FEMALE", "OTHER"]).optional(),
    medicalHistory: z.preprocess(
      normalizeOptionalString,
      z.string().max(5000).optional(),
    ),
    riskFactors: z.preprocess(
      parseOptionalJsonObject,
      z.record(z.any()).optional(),
    ),
  })
  .superRefine((data, ctx) => {
    if (Object.values(data).some((value) => value !== undefined)) return;

    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["name"],
      message: "At least one field is required",
    });
  })
  .transform(({ name, fullName, ...data }) => ({
    ...data,
    fullName: fullName ?? name,
  }));

const uploadPhotoSchema = z.object({
  file: z.instanceof(File, { message: "File is required" }),
});

module.exports = {
  updateDoctorProfileSchema,
  updateDoctorSettingsSchema,
  createDoctorPatientSchema,
  updateDoctorCreatedPatientSchema,
  uploadPhotoSchema,
};
