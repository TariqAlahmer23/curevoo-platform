// Defines request validation schemas for patient endpoints.
const { z } = require("zod");
const {
  createAccountSchema,
  loginSchema,
  resetPasswordSchema,
  changePasswordSchema,
  doctorCreatePatientSchema,
} = require("../registration/registration.validation");
const {
  bookAppointmentSchema,
  editAppointmentSchema,
} = require("../appointments/appointments.validation");
const {
  normalizeOptionalString,
  parseOptionalInteger,
  parseOptionalJsonObject,
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

const updateMeSchema = z
  .object({
    fullName: z.preprocess(
      normalizeOptionalString,
      z.string().min(2).max(100).optional(),
    ),
    phoneNumber: z.preprocess(
      normalizeOptionalString,
      z.string().min(5).max(30).optional(),
    ),
    address: z.preprocess(
      normalizeOptionalString,
      z.string().min(2).max(255).optional(),
    ),
    location: z.preprocess(
      normalizeOptionalString,
      z.string().min(2).max(255).optional(),
    ),
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
  .refine((data) => Object.values(data).some((value) => value !== undefined), {
    message: "At least one field is required",
    path: ["fullName"],
  });

const uploadTestRecordSchema = z
  .object({
    recordDate: z.coerce.date().optional(),
    recordTitle: z.string().trim().min(1).max(255).optional(),
    testRecordData: jsonValueSchema.optional(),
    aiResult: z.string().trim().min(1).max(5000).optional(),
  })
  .refine((data) => data.recordTitle || data.testRecordData !== undefined, {
    message: "recordTitle or testRecordData is required",
    path: ["recordTitle"],
  });

const registerPatientSchema = createAccountSchema;

const patientForgotPasswordSchema = z.object({
  email: z.string().email(),
});

module.exports = {
  registerPatientSchema,
  loginPatientSchema: loginSchema,
  patientForgotPasswordSchema,
  patientResetPasswordSchema: resetPasswordSchema,
  patientChangePasswordSchema: changePasswordSchema,
  updateMeSchema,
  bookPatientAppointmentSchema: bookAppointmentSchema,
  editPatientAppointmentSchema: editAppointmentSchema,
  createCreatedPatientSchema: doctorCreatePatientSchema,
  uploadTestRecordSchema,
};
