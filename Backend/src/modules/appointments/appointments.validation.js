// Defines request validation schemas for appointment endpoints.
const { z } = require("zod");
const { DATE_PATTERN, TIME_PATTERN } = require("../../common/utils/scheduling");

const dateSchema = z
  .string()
  .trim()
  .regex(DATE_PATTERN, "Invalid date format YYYY-MM-DD");

const timeSchema = z
  .string()
  .trim()
  .regex(TIME_PATTERN, "Invalid time format HH:mm");

const appointmentScheduleFields = {
  scheduledAt: z.coerce.date().optional(),
  appointmentDate: dateSchema.optional(),
  appointmentTime: timeSchema.optional(),
  reason: z.string().max(1000).optional(),
  notes: z.string().max(4000).optional(),
};

function validateScheduledInput(data, ctx) {
  const hasScheduledAt = data.scheduledAt !== undefined;
  const hasDate = data.appointmentDate !== undefined;
  const hasTime = data.appointmentTime !== undefined;

  if (!hasScheduledAt && !hasDate && !hasTime) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["scheduledAt"],
      message: "scheduledAt or appointmentDate + appointmentTime is required",
    });
  }

  if (hasDate && !hasTime) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["appointmentTime"],
      message: "appointmentTime is required when appointmentDate is provided",
    });
  }

  if (!hasDate && hasTime) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["appointmentDate"],
      message: "appointmentDate is required when appointmentTime is provided",
    });
  }
}

const bookAppointmentSchema = z.object({
  doctorUserId: z.string().min(1),
  ...appointmentScheduleFields,
}).superRefine(validateScheduledInput);

const bookDoctorAppointmentSchema = z.object({
  patientId: z.string().min(1),
  ...appointmentScheduleFields,
}).superRefine(validateScheduledInput);

const editAppointmentSchema = z.object({
  scheduledAt: z.coerce.date().optional(),
  appointmentDate: dateSchema.optional(),
  appointmentTime: timeSchema.optional(),
  reason: z.string().max(1000).optional(),
  notes: z.string().max(4000).optional(),
}).superRefine((data, ctx) => {
  if (!Object.values(data).some((value) => value !== undefined)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["scheduledAt"],
      message: "At least one field is required",
    });
  }

  if (data.appointmentDate && !data.appointmentTime) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["appointmentTime"],
      message: "appointmentTime is required when appointmentDate is provided",
    });
  }

  if (!data.appointmentDate && data.appointmentTime) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["appointmentDate"],
      message: "appointmentDate is required when appointmentTime is provided",
    });
  }
});

const respondAppointmentSchema = z.object({
  action: z.enum(["approve", "reject"]),
});

const bookedSlotsQuerySchema = z
  .object({
    date: dateSchema.optional(),
    from: dateSchema.optional(),
    to: dateSchema.optional(),
  })
  .superRefine((data, ctx) => {
    if (!data.date && !data.from && !data.to) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["date"],
        message: "date or from is required",
      });
    }

    if (data.date && (data.from || data.to)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["date"],
        message: "Use either date or from/to, not both",
      });
    }

    if (!data.date && data.to && !data.from) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["from"],
        message: "from is required when to is provided",
      });
    }
  })
  .transform((data) => ({
    from: data.date ?? data.from,
    to: data.date ?? data.to ?? data.from,
  }));

module.exports = {
  bookAppointmentSchema,
  bookDoctorAppointmentSchema,
  bookedSlotsQuerySchema,
  editAppointmentSchema,
  respondAppointmentSchema,
};
