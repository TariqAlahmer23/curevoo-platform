// Shared helpers for scheduling, availability, and appointment date/time shaping.
const { AppError } = require("../errors/AppError");

const TIME_PATTERN = /^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

function padNumber(value) {
  return String(value).padStart(2, "0");
}

function formatTimeString(value) {
  if (typeof value !== "string") return value ?? null;

  const trimmed = value.trim();
  if (!trimmed) return null;

  const match = /^(\d{1,2}):(\d{2})(?::(\d{2}))?$/.exec(trimmed);
  if (!match) return trimmed;

  return `${padNumber(Number(match[1]))}:${match[2]}`;
}

function formatDateOnly(date) {
  return [
    date.getFullYear(),
    padNumber(date.getMonth() + 1),
    padNumber(date.getDate()),
  ].join("-");
}

function formatTimeFromDate(date) {
  return `${padNumber(date.getHours())}:${padNumber(date.getMinutes())}`;
}

function createClosedAvailabilitySlot(dayOfWeek) {
  return {
    id: null,
    dayOfWeek,
    startTime: null,
    endTime: null,
    from: null,
    to: null,
    isOn: false,
    createdAt: null,
    updatedAt: null,
  };
}

function formatAvailabilitySlot(slot) {
  if (!slot) return slot;

  const startTime = formatTimeString(slot.startTime);
  const endTime = formatTimeString(slot.endTime);

  return {
    ...slot,
    startTime,
    endTime,
    from: startTime,
    to: endTime,
    isOn: slot.isOn ?? true,
  };
}

function buildWeeklyAvailability(slots = []) {
  const slotsByDay = new Map();

  for (const slot of slots) {
    if (!slot || slotsByDay.has(slot.dayOfWeek)) continue;
    slotsByDay.set(slot.dayOfWeek, slot);
  }

  return Array.from({ length: 7 }, (_, dayOfWeek) => {
    const slot = slotsByDay.get(dayOfWeek);
    return slot
      ? formatAvailabilitySlot(slot)
      : createClosedAvailabilitySlot(dayOfWeek);
  });
}

function parseTimeToMinutes(timeStr) {
  const match = /^(\d{1,2}):(\d{2})(?::(\d{2}))?$/.exec(timeStr || "");
  if (!match) return null;

  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  if (Number.isNaN(hours) || Number.isNaN(minutes)) return null;

  return hours * 60 + minutes;
}

function parseDateOnly(dateString, fieldName = "date") {
  const trimmed =
    typeof dateString === "string" ? dateString.trim() : dateString;

  if (typeof trimmed !== "string" || !DATE_PATTERN.test(trimmed)) {
    throw new AppError(
      `Invalid ${fieldName} format. Use YYYY-MM-DD`,
      400,
      "INVALID_DATE",
    );
  }

  const [year, month, day] = trimmed.split("-").map(Number);
  const date = new Date(year, month - 1, day);

  if (
    Number.isNaN(date.getTime()) ||
    date.getFullYear() !== year ||
    date.getMonth() !== month - 1 ||
    date.getDate() !== day
  ) {
    throw new AppError(
      `Invalid ${fieldName} value`,
      400,
      "INVALID_DATE",
    );
  }

  date.setHours(0, 0, 0, 0);
  return date;
}

function combineDateAndTime(
  dateString,
  timeString,
  code = "INVALID_APPOINTMENT_TIME",
) {
  const normalizedTime =
    typeof timeString === "string" ? timeString.trim() : timeString;

  if (!TIME_PATTERN.test(normalizedTime || "")) {
    throw new AppError(
      "Invalid appointment time format. Use HH:mm",
      400,
      code,
    );
  }

  const date = parseDateOnly(dateString, "appointmentDate");
  const [hours, minutes] = normalizedTime.split(":").map(Number);
  date.setHours(hours, minutes, 0, 0);

  return date;
}

function getDateWindow(dateString, fieldName = "date") {
  const start = parseDateOnly(dateString, fieldName);
  const end = new Date(start);
  end.setDate(end.getDate() + 1);

  return {
    date: start,
    start,
    end,
    dayOfWeek: start.getDay(),
    dateString: formatDateOnly(start),
  };
}

function formatAppointment(appointment) {
  if (!appointment) return appointment;

  const scheduledAt = new Date(appointment.scheduledAt);
  if (Number.isNaN(scheduledAt.getTime())) {
    return appointment;
  }

  return {
    ...appointment,
    appointmentDate: formatDateOnly(scheduledAt),
    appointmentTime: formatTimeFromDate(scheduledAt),
  };
}

function formatBookedAppointmentSlot(appointment, options = {}) {
  const scheduledAt = new Date(appointment.scheduledAt);
  const result = {
    scheduledAt: appointment.scheduledAt,
    appointmentDate: formatDateOnly(scheduledAt),
    appointmentTime: formatTimeFromDate(scheduledAt),
    status: appointment.status,
  };

  if (options.includeAppointmentId && appointment.id) {
    result.appointmentId = appointment.id;
  }

  if (options.includePatientUserId && appointment.patientUserId) {
    result.patientUserId = appointment.patientUserId;
  }

  if (options.includeCreatedPatientId && appointment.createdPatientId) {
    result.createdPatientId = appointment.createdPatientId;
  }

  if (options.includePatientSubject) {
    result.patientId =
      appointment.createdPatientId || appointment.patientUserId || null;
    result.patientType = appointment.createdPatientId ? "CREATED" : "NORMAL";
  }

  if (options.includePatientName) {
    result.patientName =
      appointment.createdPatient?.fullName ||
      appointment.patient?.patientProfile?.fullName ||
      appointment.patient?.name ||
      null;
  }

  if (options.includeReason) {
    result.reason = appointment.reason ?? null;
  }

  if (options.includeDoctorUserId && appointment.doctorUserId) {
    result.doctorUserId = appointment.doctorUserId;
  }

  return result;
}

module.exports = {
  TIME_PATTERN,
  DATE_PATTERN,
  buildWeeklyAvailability,
  combineDateAndTime,
  createClosedAvailabilitySlot,
  formatAppointment,
  formatAvailabilitySlot,
  formatBookedAppointmentSlot,
  formatDateOnly,
  formatTimeFromDate,
  formatTimeString,
  getDateWindow,
  parseDateOnly,
  parseTimeToMinutes,
};
