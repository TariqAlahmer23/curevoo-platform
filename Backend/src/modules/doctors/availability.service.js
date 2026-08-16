// Implements doctor availability scheduling rules and status management.
const { AppError } = require("../../common/errors/AppError");
const {
  buildWeeklyAvailability,
  createClosedAvailabilitySlot,
  formatAvailabilitySlot,
  formatBookedAppointmentSlot,
  getDateWindow,
} = require("../../common/utils/scheduling");
const { listBookedAppointmentsByDoctorUserId } = require("../appointments/appointments.repo");
const {
  findDoctorProfileByUserId,
  createAvailableTime,
  getAvailableTimesByDoctor,
  getAvailableTimeById,
  getAvailableTimeByDay,
  updateAvailableTime,
  deleteAvailableTimesByDay,
  deleteAvailableTime,
  updateDoctorStatus,
  getDoctorStatus,
} = require("./availability.repo");

function validateTimeRange(data) {
  const startTime = data.startTime ?? null;
  const endTime = data.endTime ?? null;
  const isOn = data.isOn ?? true;

  if (!isOn) {
    if ((startTime && !endTime) || (!startTime && endTime)) {
      throw new AppError(
        "Both from and to must be provided together",
        400,
        "INVALID_TIME_RANGE",
      );
    }

    return {
      ...data,
      startTime,
      endTime,
      isOn,
    };
  }

  if (!startTime || !endTime) {
    throw new AppError(
      "from and to are required when the day is on",
      400,
      "INVALID_TIME_RANGE",
    );
  }

  if (startTime >= endTime) {
    throw new AppError(
      "Start time must be before end time",
      400,
      "INVALID_TIME_RANGE",
    );
  }

  return {
    ...data,
    startTime,
    endTime,
    isOn,
  };
}

async function getDoctorProfileOrThrow(userId) {
  const doctorProfile = await findDoctorProfileByUserId(userId);

  if (!doctorProfile) {
    throw new AppError("Doctor profile not found", 404, "PROFILE_NOT_FOUND");
  }

  return doctorProfile;
}

// Available Times
async function createAvailableTimeSlot(userId, data) {
  const doctorProfile = await getDoctorProfileOrThrow(userId);

  const normalizedData = validateTimeRange(data);
  await deleteAvailableTimesByDay(doctorProfile.id, normalizedData.dayOfWeek);

  const created = await createAvailableTime(doctorProfile.id, normalizedData);
  return formatAvailabilitySlot(created);
}

// Executes the "get available times" business workflow for this module.
async function getAvailableTimes(userId) {
  const doctorProfile = await getDoctorProfileOrThrow(userId);

  const slots = await getAvailableTimesByDoctor(doctorProfile.id);
  return buildWeeklyAvailability(slots);
}

// Executes the "get available times by date" business workflow for this module.
async function getAvailableTimesForDate(userId, dateString) {
  const doctorProfile = await getDoctorProfileOrThrow(userId);
  const dateWindow = getDateWindow(dateString);

  const [slot, appointments] = await Promise.all([
    getAvailableTimeByDay(doctorProfile.id, dateWindow.dayOfWeek),
    listBookedAppointmentsByDoctorUserId(
      doctorProfile.userId,
      dateWindow.start,
      dateWindow.end,
    ),
  ]);

  const availability = slot
    ? formatAvailabilitySlot(slot)
    : createClosedAvailabilitySlot(dateWindow.dayOfWeek);
  const bookedSlots = appointments.map((appointment) =>
    formatBookedAppointmentSlot(appointment, {
      includeAppointmentId: true,
      includePatientUserId: true,
      includeCreatedPatientId: true,
      includeDoctorUserId: true,
      includePatientSubject: true,
      includePatientName: true,
    }),
  );

  return {
    doctorId: doctorProfile.id,
    doctorUserId: doctorProfile.userId,
    date: dateWindow.dateString,
    dayOfWeek: dateWindow.dayOfWeek,
    availability,
    isAvailableDay: Boolean(
      availability.isOn && availability.from && availability.to,
    ),
    bookedTimes: bookedSlots.map((slotItem) => slotItem.appointmentTime),
    bookedSlots,
  };
}

// Executes the "update available time slot" business workflow for this module.
async function updateAvailableTimeSlot(userId, data) {
  const doctorProfile = await getDoctorProfileOrThrow(userId);

  const existingSlot = await getAvailableTimeByDay(
    doctorProfile.id,
    data.dayOfWeek,
  );

  const normalizedData = validateTimeRange({
    dayOfWeek: data.dayOfWeek,
    startTime:
      data.startTime !== undefined
        ? data.startTime
        : existingSlot?.startTime ?? null,
    endTime:
      data.endTime !== undefined ? data.endTime : existingSlot?.endTime ?? null,
    isOn: data.isOn !== undefined ? data.isOn : existingSlot?.isOn ?? true,
  });

  await deleteAvailableTimesByDay(
    doctorProfile.id,
    normalizedData.dayOfWeek,
    existingSlot?.id || null,
  );

  if (!existingSlot) {
    const created = await createAvailableTime(doctorProfile.id, normalizedData);
    return formatAvailabilitySlot(created);
  }

  const updated = await updateAvailableTime(existingSlot.id, normalizedData);
  return formatAvailabilitySlot(updated);
}

// Executes the "delete available time slot" business workflow for this module.
async function deleteAvailableTimeSlot(userId, availableTimeId) {
  const doctorProfile = await getDoctorProfileOrThrow(userId);

  // Ensure doctor can only delete their own slot.
  const existingSlot = await getAvailableTimeById(
    availableTimeId,
    doctorProfile.id,
  );
  if (!existingSlot) {
    throw new AppError("Available time slot not found", 404, "SLOT_NOT_FOUND");
  }

  return deleteAvailableTime(availableTimeId);
}

// Doctor Status
async function updateStatus(userId, isActive) {
  await getDoctorProfileOrThrow(userId);

  return updateDoctorStatus(userId, isActive);
}

// Executes the "get status" business workflow for this module.
async function getStatus(userId) {
  const status = await getDoctorStatus(userId);
  if (!status) {
    throw new AppError("Doctor profile not found", 404, "PROFILE_NOT_FOUND");
  }
  return status;
}

module.exports = {
  createAvailableTimeSlot,
  getAvailableTimes,
  getAvailableTimesForDate,
  updateAvailableTimeSlot,
  deleteAvailableTimeSlot,
  updateStatus,
  getStatus,
};
