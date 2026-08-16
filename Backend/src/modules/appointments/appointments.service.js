// Enforces scheduling rules for appointment booking, updates, and doctor responses.
const { AppError } = require("../../common/errors/AppError");
const {
  combineDateAndTime,
  formatAppointment,
  formatBookedAppointmentSlot,
  getDateWindow,
  parseTimeToMinutes,
} = require("../../common/utils/scheduling");
const repo = require("./appointments.repo");

const MIN_HOURS_BEFORE_CHANGE = 2;

// Checks whether a scheduled date falls within one of the doctor availability slots.
function isWithinAvailableSlot(scheduledAt, availableTimes) {
  if (!Array.isArray(availableTimes) || availableTimes.length === 0) {
    return false;
  }
  const dayOfWeek = scheduledAt.getDay();
  const minutesOfDay =
    scheduledAt.getHours() * 60 + scheduledAt.getMinutes();

  return availableTimes.some((slot) => {
    if (slot.dayOfWeek !== dayOfWeek) return false;
    if (slot.isOn === false) return false;
    const startMinutes = parseTimeToMinutes(slot.startTime);
    const endMinutes = parseTimeToMinutes(slot.endTime);
    if (startMinutes === null || endMinutes === null) return false;
    return minutesOfDay >= startMinutes && minutesOfDay <= endMinutes;
  });
}

// Rejects dates that are invalid or not in the future.
function ensureFutureDate(date, code = "INVALID_APPOINTMENT_TIME") {
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
    throw new AppError("Invalid appointment date", 400, code);
  }
  if (date <= new Date()) {
    throw new AppError(
      "Appointment time must be in the future",
      400,
      code,
    );
  }
}

function getScheduledAtFromInput(
  data,
  { required = false, code = "INVALID_APPOINTMENT_TIME" } = {},
) {
  if (data.scheduledAt instanceof Date) {
    return data.scheduledAt;
  }

  if (data.appointmentDate || data.appointmentTime) {
    if (!data.appointmentDate || !data.appointmentTime) {
      throw new AppError(
        "appointmentDate and appointmentTime must be provided together",
        400,
        code,
      );
    }

    return combineDateAndTime(data.appointmentDate, data.appointmentTime, code);
  }

  if (required) {
    throw new AppError(
      "scheduledAt or appointmentDate + appointmentTime is required",
      400,
      code,
    );
  }

  return undefined;
}

function formatAppointmentRecord(item) {
  if (!item) return item;

  const formatted = formatAppointment(item);
  const patientId = item.createdPatientId || item.patientUserId || null;
  const patientType = item.createdPatientId ? "CREATED" : "NORMAL";
  const patientName =
    item.createdPatient?.fullName ||
    item.patient?.patientProfile?.fullName ||
    item.patient?.name ||
    null;
  const patientPhoneNumber =
    item.createdPatient?.phoneNumber || item.patient?.phoneNumber || null;

  return {
    ...formatted,
    patientId,
    patientType,
    patientName,
    patientUserId: item.patientUserId ?? null,
    createdPatientId: item.createdPatientId ?? null,
    patient:
      patientType === "CREATED"
        ? {
            id: item.createdPatient?.id || patientId,
            patientType,
            fullName: patientName,
            name: patientName,
            phoneNumber: patientPhoneNumber,
            sourcePatientUserId: item.createdPatient?.sourcePatientUserId || null,
            email: null,
          }
        : {
            id: item.patient?.id || patientId,
            patientType,
            fullName: patientName,
            name: patientName,
            phoneNumber: patientPhoneNumber,
            email: item.patient?.email || null,
          },
  };
}

function formatAppointments(items) {
  return items.map(formatAppointmentRecord);
}

// Rejects appointment changes that violate the minimum lead time rule.
function ensureCanChangeByTime(scheduledAt) {
  const msLeft = new Date(scheduledAt).getTime() - Date.now();
  const hoursLeft = msLeft / (1000 * 60 * 60);
  if (hoursLeft < MIN_HOURS_BEFORE_CHANGE) {
    throw new AppError(
      `Appointment can only be changed at least ${MIN_HOURS_BEFORE_CHANGE} hours before schedule`,
      400,
      "APPOINTMENT_CHANGE_TIME_RESTRICTED",
    );
  }
}

async function ensureBookableDoctor(doctorUserId) {
  const doctor = await repo.findDoctorUserById(doctorUserId);
  if (!doctor || doctor.role !== "DOCTOR") {
    throw new AppError("Doctor not found", 404, "DOCTOR_NOT_FOUND");
  }
  if (!doctor.doctorProfile?.isActive) {
    throw new AppError("Doctor is not active", 400, "DOCTOR_INACTIVE");
  }
  return doctor;
}

async function ensureDoctorSlotIsBookable(
  doctorUserId,
  scheduledAt,
  conflictAppointmentId = null,
) {
  const availability = await repo.getDoctorAvailabilityByUserId(doctorUserId);
  if (
    !availability ||
    !isWithinAvailableSlot(scheduledAt, availability.availableTimes)
  ) {
    throw new AppError(
      "Selected time is unavailable",
      400,
      "TIME_UNAVAILABLE",
    );
  }

  const conflict = await repo.findDoctorAppointmentConflict(
    doctorUserId,
    scheduledAt,
  );
  if (conflict && conflict.id !== conflictAppointmentId) {
    throw new AppError(
      "Selected time is already booked",
      409,
      "APPOINTMENT_CONFLICT",
    );
  }
}

// Executes the "book appointment" business workflow for this module.
async function bookAppointment(patientUserId, data) {
  const scheduledAt = getScheduledAtFromInput(data, { required: true });
  ensureFutureDate(scheduledAt);

  await ensureBookableDoctor(data.doctorUserId);
  await ensureDoctorSlotIsBookable(data.doctorUserId, scheduledAt);

  const appointment = await repo.createAppointment({
    patientUserId,
    doctorUserId: data.doctorUserId,
    scheduledAt,
    reason: data.reason ?? null,
    notes: data.notes ?? null,
    status: "PENDING",
  });

  return formatAppointmentRecord(appointment);
}

// Executes the "book appointment as doctor" business workflow for this module.
async function bookDoctorAppointment(doctorUserId, data) {
  const scheduledAt = getScheduledAtFromInput(data, { required: true });
  ensureFutureDate(scheduledAt);

  await ensureBookableDoctor(doctorUserId);
  await ensureDoctorSlotIsBookable(doctorUserId, scheduledAt);

  const patient = await repo.findDoctorAppointmentSubject(
    doctorUserId,
    data.patientId,
  );
  if (!patient) {
    throw new AppError("Patient not found", 404, "PATIENT_NOT_FOUND");
  }

  const appointment = await repo.createAppointment({
    patientUserId: patient.patientUserId,
    createdPatientId: patient.createdPatientId,
    doctorUserId,
    scheduledAt,
    reason: data.reason ?? null,
    notes: data.notes ?? null,
    status: "CREATED",
  });

  return formatAppointmentRecord(appointment);
}

// Executes the "view appointments" business workflow for this module.
async function viewAppointments(patientUserId) {
  return formatAppointments(await repo.listPatientAppointments(patientUserId));
}

// Executes the "edit appointment" business workflow for this module.
async function editAppointment(patientUserId, appointmentId, data) {
  const appointment = await repo.findAppointmentById(appointmentId);
  if (!appointment) {
    throw new AppError("Appointment not found", 404, "APPOINTMENT_NOT_FOUND");
  }
  if (appointment.patientUserId !== patientUserId) {
    throw new AppError("Forbidden", 403, "FORBIDDEN");
  }
  if (appointment.status === "CANCELED") {
    throw new AppError(
      "Cannot edit canceled appointment",
      400,
      "APPOINTMENT_ALREADY_CANCELED",
    );
  }

  ensureCanChangeByTime(appointment.scheduledAt);
  const scheduledAt = getScheduledAtFromInput(data, {
    code: "INVALID_NEW_TIME",
  });

  if (scheduledAt) {
    ensureFutureDate(scheduledAt, "INVALID_NEW_TIME");
    await ensureDoctorSlotIsBookable(
      appointment.doctorUserId,
      scheduledAt,
      appointment.id,
    );
  }

  const shouldResetApproval =
    scheduledAt &&
    new Date(appointment.scheduledAt).getTime() !== scheduledAt.getTime();

  const updated = await repo.updateAppointmentById(appointmentId, {
    scheduledAt: scheduledAt ?? undefined,
    reason: data.reason ?? undefined,
    notes: data.notes ?? undefined,
    ...(shouldResetApproval
      ? {
          status: "PENDING",
          canceledAt: null,
        }
      : {}),
  });

  return formatAppointmentRecord(updated);
}

// Executes the doctor-side "edit appointment" business workflow for this module.
async function editDoctorAppointment(doctorUserId, appointmentId, data) {
  const appointment = await repo.findAppointmentById(appointmentId);
  if (!appointment) {
    throw new AppError("Appointment not found", 404, "APPOINTMENT_NOT_FOUND");
  }
  if (appointment.doctorUserId !== doctorUserId) {
    throw new AppError("Forbidden", 403, "FORBIDDEN");
  }
  if (appointment.status === "CANCELED") {
    throw new AppError(
      "Cannot edit canceled appointment",
      400,
      "APPOINTMENT_ALREADY_CANCELED",
    );
  }

  ensureCanChangeByTime(appointment.scheduledAt);
  const scheduledAt = getScheduledAtFromInput(data, {
    code: "INVALID_NEW_TIME",
  });

  if (scheduledAt) {
    ensureFutureDate(scheduledAt, "INVALID_NEW_TIME");
    await ensureDoctorSlotIsBookable(doctorUserId, scheduledAt, appointment.id);
  }

  const updated = await repo.updateAppointmentById(appointmentId, {
    scheduledAt: scheduledAt ?? undefined,
    reason: data.reason ?? undefined,
    notes: data.notes ?? undefined,
  });

  return formatAppointmentRecord(updated);
}

// Executes the "cancel appointment" business workflow for this module.
async function cancelAppointment(patientUserId, appointmentId) {
  const appointment = await repo.findAppointmentById(appointmentId);
  if (!appointment) {
    throw new AppError("Appointment not found", 404, "APPOINTMENT_NOT_FOUND");
  }
  if (appointment.patientUserId !== patientUserId) {
    throw new AppError("Forbidden", 403, "FORBIDDEN");
  }
  if (appointment.status === "CANCELED") {
    return formatAppointmentRecord(appointment);
  }

  ensureCanChangeByTime(appointment.scheduledAt);
  const updated = await repo.updateAppointmentById(appointmentId, {
    status: "CANCELED",
    canceledAt: new Date(),
  });

  return formatAppointmentRecord(updated);
}

// Executes the "delete appointment" business workflow for this module.
async function deleteAppointment(patientUserId, appointmentId) {
  const appointment = await repo.findAppointmentById(appointmentId);
  if (!appointment) {
    throw new AppError("Appointment not found", 404, "APPOINTMENT_NOT_FOUND");
  }
  if (appointment.patientUserId !== patientUserId) {
    throw new AppError("Forbidden", 403, "FORBIDDEN");
  }
  await repo.deleteAppointmentById(appointmentId);
  return { id: appointmentId, deleted: true };
}

// Executes the doctor-side "delete appointment" business workflow for this module.
async function deleteDoctorAppointment(doctorUserId, appointmentId) {
  const appointment = await repo.findAppointmentById(appointmentId);
  if (!appointment) {
    throw new AppError("Appointment not found", 404, "APPOINTMENT_NOT_FOUND");
  }
  if (appointment.doctorUserId !== doctorUserId) {
    throw new AppError("Forbidden", 403, "FORBIDDEN");
  }
  await repo.deleteAppointmentById(appointmentId);
  return { id: appointmentId, deleted: true };
}

// Executes the "list doctor appointments" business workflow for this module.
async function listDoctorAppointments(doctorUserId, status = null) {
  const allowed = new Set(["PENDING", "CREATED", "CONFIRMED", "CANCELED"]);
  const rawStatus =
    typeof status === "string" ? status.trim().toUpperCase() : null;
  const normalizedStatus =
    rawStatus === "BOOKED"
      ? "CONFIRMED"
      : rawStatus === "REJECTED"
        ? "CANCELED"
        : rawStatus === "ACCEPTED"
          ? "CONFIRMED"
          : rawStatus;

  if (!normalizedStatus || normalizedStatus === "ALL") {
    return formatAppointments(await repo.listDoctorAppointments(doctorUserId));
  }

  if (!allowed.has(normalizedStatus)) {
    throw new AppError("Invalid status filter", 400, "INVALID_STATUS");
  }
  return formatAppointments(
    await repo.listDoctorAppointments(doctorUserId, normalizedStatus),
  );
}

// Executes the "list upcoming doctor appointments" business workflow.
async function listUpcomingDoctorAppointments(doctorUserId) {
  return formatAppointments(
    await repo.listUpcomingDoctorAppointments(doctorUserId),
  );
}

// Executes the "respond to appointment" business workflow for this module.
async function respondToAppointment(doctorUserId, appointmentId, action) {
  const appointment = await repo.findAppointmentById(appointmentId);
  if (!appointment) {
    throw new AppError("Appointment not found", 404, "APPOINTMENT_NOT_FOUND");
  }
  if (appointment.doctorUserId !== doctorUserId) {
    throw new AppError("Forbidden", 403, "FORBIDDEN");
  }
  if (appointment.status !== "PENDING") {
    throw new AppError(
      "Appointment is not pending",
      400,
      "APPOINTMENT_NOT_PENDING",
    );
  }

  const nextStatus = action === "approve" ? "CONFIRMED" : "CANCELED";
  const updated = await repo.updateAppointmentById(appointmentId, {
    status: nextStatus,
    canceledAt: action === "approve" ? null : new Date(),
  });

  return formatAppointmentRecord(updated);
}

// Executes the "list doctor booked slots" business workflow for this module.
async function getDoctorBookedSlots(doctorUserId, query) {
  const fromWindow = getDateWindow(query.from, "from");
  const toWindow = getDateWindow(query.to, "to");

  if (toWindow.start.getTime() < fromWindow.start.getTime()) {
    throw new AppError(
      "to must be on or after from",
      400,
      "INVALID_DATE_RANGE",
    );
  }

  const appointments = await repo.listBookedAppointmentsByDoctorUserId(
    doctorUserId,
    fromWindow.start,
    toWindow.end,
  );
  const bookedSlots = appointments.map((appointment) =>
    formatBookedAppointmentSlot(appointment, {
      includeAppointmentId: true,
      includePatientUserId: true,
      includeCreatedPatientId: true,
      includeDoctorUserId: true,
      includePatientSubject: true,
      includePatientName: true,
      includeReason: true,
    }),
  );

  return {
    from: fromWindow.dateString,
    to: toWindow.dateString,
    total: bookedSlots.length,
    bookedSlots,
  };
}

// Executes the "get one doctor booked slot" business workflow for this module.
async function getDoctorBookedSlotById(doctorUserId, appointmentId) {
  const appointment = await repo.findBookedAppointmentByIdForDoctor(
    doctorUserId,
    appointmentId,
  );

  if (!appointment) {
    throw new AppError("Booked slot not found", 404, "BOOKED_SLOT_NOT_FOUND");
  }

  return formatBookedAppointmentSlot(appointment, {
    includeAppointmentId: true,
    includePatientUserId: true,
    includeCreatedPatientId: true,
    includeDoctorUserId: true,
    includePatientSubject: true,
    includePatientName: true,
    includeReason: true,
  });
}

module.exports = {
  bookAppointment,
  bookDoctorAppointment,
  viewAppointments,
  editAppointment,
  editDoctorAppointment,
  cancelAppointment,
  deleteAppointment,
  deleteDoctorAppointment,
  getDoctorBookedSlots,
  getDoctorBookedSlotById,
  listDoctorAppointments,
  listUpcomingDoctorAppointments,
  respondToAppointment,
};
