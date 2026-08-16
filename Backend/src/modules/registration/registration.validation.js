// Defines request validation schemas for registration and QR-related endpoints.
const { z } = require("zod");
const {
  normalizeOptionalString,
  parseOptionalInteger,
  parseOptionalJsonObject,
  parseStringArray,
} = require("../../common/utils/inputParsers");

const roleEnum = z.enum(["PATIENT", "DOCTOR", "ADMIN"]);
const otpPurposeEnum = z.enum(["EMAIL_VERIFICATION", "PASSWORD_RESET"]);
const deletionActionEnum = z.enum(["KEEP_AS_CREATED_PATIENT", "REMOVE_ONLY"]);
const connectionActionEnum = z.enum(["ACCEPT", "REJECT"]);
const compromisedPasswordBlocklist = new Set([
  "123456",
  "123456789",
  "12345678",
  "password",
  "qwerty",
  "111111",
  "123123",
  "abc123",
  "password1",
  "iloveyou",
  "admin",
  "welcome",
  "letmein",
  "1234567",
  "monkey",
  "dragon",
  "football",
  "baseball",
  "sunshine",
  "princess",
]);

function validateStrongPassword(value) {
  const password = String(value || "");
  if (password.length < 12 || password.length > 128) return false;
  if (!/[a-z]/.test(password)) return false;
  if (!/[A-Z]/.test(password)) return false;
  if (!/[0-9]/.test(password)) return false;
  if (!/[^A-Za-z0-9]/.test(password)) return false;
  if (/\s/.test(password)) return false;
  return true;
}

const strongPasswordSchema = z
  .string()
  .refine(validateStrongPassword, {
    message:
      "Password must be 12-128 chars and include upper/lowercase letters, a number, and a symbol.",
  })
  .refine((value) => !compromisedPasswordBlocklist.has(value.toLowerCase()), {
    message: "This password is too common or appears in compromised password lists.",
  });

const optionalShortText = z.preprocess(
  normalizeOptionalString,
  z.string().min(2).max(100).optional(),
);

const optionalLongText = z.preprocess(
  normalizeOptionalString,
  z.string().min(2).max(255).optional(),
);

const optionalPhoneNumber = z.preprocess(
  normalizeOptionalString,
  z.string().min(5).max(30).optional(),
);

const optionalAge = z.preprocess(
  parseOptionalInteger,
  z.number().int().min(18).max(120).optional(),
);

const optionalExperience = z.preprocess(
  parseOptionalInteger,
  z.number().int().min(0).max(70).optional(),
);

const optionalLanguages = z.preprocess(
  parseStringArray,
  z.array(z.string().min(2).max(50)).min(1).max(20).optional(),
);

const createAccountSchema = z
  .object({
    email: z.string().email(),
    password: strongPasswordSchema,
    fullName: optionalShortText,
    name: optionalShortText,
    phoneNumber: optionalPhoneNumber,
    age: optionalAge,
    specialization: optionalShortText,
    workplace: optionalLongText,
    experience: optionalExperience,
    location: optionalLongText,
    languages: optionalLanguages,
    role: roleEnum.default("PATIENT"),
  })
  .superRefine((data, ctx) => {
    if (data.role !== "DOCTOR") return;

    const fullName = data.name || data.fullName;
    const requiredDoctorFields = [
      ["name", fullName],
      ["phoneNumber", data.phoneNumber],
      ["age", data.age],
      ["specialization", data.specialization],
      ["workplace", data.workplace],
      ["experience", data.experience],
      ["location", data.location],
      ["languages", data.languages],
    ];

    for (const [field, value] of requiredDoctorFields) {
      if (
        value === undefined ||
        value === null ||
        (Array.isArray(value) && value.length === 0)
      ) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: [field],
          message: `${field} is required for doctor registration`,
        });
      }
    }
  })
  .transform(({ name, workplace, ...data }) => ({
    ...data,
    fullName: name || data.fullName,
    workingAt: workplace,
  }));

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const sendOtpSchema = z.object({
  email: z.string().email(),
  purpose: otpPurposeEnum,
});

const verifyOtpSchema = z.object({
  email: z.string().email(),
  otp: z.string().length(6),
  purpose: otpPurposeEnum,
});

const resetPasswordSchema = z.object({
  email: z.string().email(),
  otp: z.string().length(6),
  newPassword: strongPasswordSchema,
});

const changePasswordSchema = z
  .object({
    currentPassword: z.string().min(1),
    newPassword: strongPasswordSchema,
  })
  .refine((data) => data.currentPassword !== data.newPassword, {
    message: "New password must be different from current password",
    path: ["newPassword"],
  });

const doctorCreatePatientSchema = z
  .object({
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

const respondDeletionRequestSchema = z.object({
  action: deletionActionEnum,
});

const scanQrSchema = z.object({
  qrCode: z.string().min(8).max(512),
});

const respondConnectionRequestSchema = z.object({
  action: connectionActionEnum,
});

module.exports = {
  createAccountSchema,
  loginSchema,
  sendOtpSchema,
  verifyOtpSchema,
  resetPasswordSchema,
  changePasswordSchema,
  doctorCreatePatientSchema,
  respondDeletionRequestSchema,
  scanQrSchema,
  respondConnectionRequestSchema,
};
