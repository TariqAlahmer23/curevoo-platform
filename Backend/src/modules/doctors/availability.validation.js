// Defines request validation schemas for doctor availability and status endpoints.
const { z } = require("zod");
const { DATE_PATTERN, TIME_PATTERN } = require("../../common/utils/scheduling");

const timeSchema = z
  .string()
  .trim()
  .regex(TIME_PATTERN, "Invalid time format HH:mm");

const dateSchema = z
  .string()
  .trim()
  .regex(DATE_PATTERN, "Invalid date format YYYY-MM-DD");

const availabilityBaseSchema = z.object({
  dayOfWeek: z
    .number()
    .int()
    .min(0)
    .max(6)
    .describe("Day of week: 0=Sunday, 6=Saturday"),
  from: timeSchema.optional(),
  to: timeSchema.optional(),
  startTime: timeSchema.optional(),
  endTime: timeSchema.optional(),
  isOn: z.boolean().optional(),
});

const createAvailableTimeSchema = availabilityBaseSchema
  .superRefine((data, ctx) => {
    const from = data.from ?? data.startTime;
    const to = data.to ?? data.endTime;
    const isOn = data.isOn ?? true;

    if (!isOn) return;

    if (!from) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["from"],
        message: "from is required when the day is on",
      });
    }

    if (!to) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["to"],
        message: "to is required when the day is on",
      });
    }
  })
  .transform(({ from, to, startTime, endTime, isOn, ...data }) => ({
    ...data,
    startTime: startTime ?? from ?? null,
    endTime: endTime ?? to ?? null,
    isOn: isOn ?? true,
  }));

const updateAvailableTimeSchema = availabilityBaseSchema
  .partial()
  .extend({
    dayOfWeek: z
      .number()
      .int()
      .min(0)
      .max(6)
      .describe("Day of week: 0=Sunday, 6=Saturday"),
  })
  .superRefine((data, ctx) => {
    if (
      data.from !== undefined ||
      data.to !== undefined ||
      data.startTime !== undefined ||
      data.endTime !== undefined ||
      data.isOn !== undefined
    ) {
      return;
    }

    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["from"],
      message: "At least one field besides dayOfWeek is required",
    });
  })
  .transform(({ from, to, startTime, endTime, isOn, ...data }) => ({
    ...data,
    startTime: startTime ?? from,
    endTime: endTime ?? to,
    isOn,
  }));

const updateDoctorStatusSchema = z.object({
  isActive: z.boolean().describe("Active/Inactive status"),
});

const availabilityDateQuerySchema = z.object({
  date: dateSchema,
});

module.exports = {
  createAvailableTimeSchema,
  availabilityDateQuerySchema,
  updateAvailableTimeSchema,
  updateDoctorStatusSchema,
};
