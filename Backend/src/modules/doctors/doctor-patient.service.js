// Shapes doctor directory responses for patient clients.
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
  getActiveDoctorProfiles,
  getActiveDoctorProfileForDate,
  getDoctorProfileWithAvailability,
} = require("./doctor-patient.repo");

// Shapes doctor directory data before returning it to patient clients.
function formatDoctor(doctor) {
  if (!doctor) return doctor;

  return {
    ...doctor,
    name: doctor.fullName || null,
    email: doctor.user?.email || null,
    phoneNumber: doctor.user?.phoneNumber || null,
    languages: Array.isArray(doctor.languages) ? doctor.languages : [],
    availableTimes: Array.isArray(doctor.availableTimes)
      ? doctor.availableTimes.map(formatAvailabilitySlot)
      : doctor.availableTimes,
    weeklyAvailability: buildWeeklyAvailability(doctor.availableTimes || []),
  };
}

// Executes the "get active doctors" business workflow for this module.
async function getActiveDoctors(specialization = null) {
  const doctors = await getActiveDoctorProfiles(specialization);
  const total = doctors.length;

  return {
    data: doctors.map(formatDoctor),
    pagination: {
      page: 1,
      total,
      pages: total > 0 ? 1 : 0,
    },
  };
}

// Executes the "get doctor detail" business workflow for this module.
async function getDoctorDetail(doctorId) {
  const doctor = await getDoctorProfileWithAvailability(doctorId);

  if (!doctor) {
    throw new AppError("Doctor not found or inactive", 404, "DOCTOR_NOT_FOUND");
  }

  return formatDoctor(doctor);
}

// Executes the "get doctor availability for date" business workflow for this module.
async function getDoctorAvailabilityForDate(doctorId, dateString) {
  const dateWindow = getDateWindow(dateString);
  const doctor = await getActiveDoctorProfileForDate(
    doctorId,
    dateWindow.dayOfWeek,
  );

  if (!doctor) {
    throw new AppError("Doctor not found or inactive", 404, "DOCTOR_NOT_FOUND");
  }

  const appointments = await listBookedAppointmentsByDoctorUserId(
    doctor.userId,
    dateWindow.start,
    dateWindow.end,
  );
  const bookedSlots = appointments.map((appointment) =>
    formatBookedAppointmentSlot(appointment),
  );
  const availability = doctor.availableTimes?.length
    ? formatAvailabilitySlot(doctor.availableTimes[0])
    : createClosedAvailabilitySlot(dateWindow.dayOfWeek);

  return {
    doctorId: doctor.id,
    doctorUserId: doctor.userId,
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

module.exports = {
  getActiveDoctors,
  getDoctorDetail,
  getDoctorAvailabilityForDate,
};
