// Handles patient-facing doctor listing and doctor detail queries.
const prisma = require("../../prisma/client");

function selectAvailableTimeFields() {
  return {
    id: true,
    dayOfWeek: true,
    startTime: true,
    endTime: true,
    isOn: true,
  };
}

function selectDoctorContactFields() {
  return {
    email: true,
    phoneNumber: true,
  };
}

// Executes the database operation for "get active doctor profiles".
async function getActiveDoctorProfiles(specialization = null) {
  const where = { isActive: true };
  if (specialization) {
    where.specialization = {
      contains: specialization,
      mode: "insensitive",
    };
  }

  return prisma.doctorProfile.findMany({
    where,
    select: {
      id: true,
      userId: true,
      fullName: true,
      specialization: true,
      workingAt: true,
      languages: true,
      location: true,
      qualifications: true,
      experience: true,
      bio: true,
      photoUrl: true,
      consultationFee: true,
      user: {
        select: selectDoctorContactFields(),
      },
      createdAt: true,
      updatedAt: true,
    },
    orderBy: { fullName: "asc" },
  });
}

// Executes the database operation for "get doctor available times".
async function getDoctorAvailableTimes(doctorId) {
  return prisma.doctorAvailableTime.findMany({
    where: { doctorId },
    select: selectAvailableTimeFields(),
    orderBy: [{ dayOfWeek: "asc" }, { startTime: "asc" }],
  });
}

// Executes the database operation for "get doctor profile with availability".
async function getDoctorProfileWithAvailability(doctorId) {
  return prisma.doctorProfile.findFirst({
    where: { id: doctorId, isActive: true },
    select: {
      id: true,
      userId: true,
      fullName: true,
      specialization: true,
      workingAt: true,
      languages: true,
      location: true,
      qualifications: true,
      experience: true,
      bio: true,
      photoUrl: true,
      consultationFee: true,
      user: {
        select: selectDoctorContactFields(),
      },
      availableTimes: {
        select: selectAvailableTimeFields(),
        orderBy: [{ dayOfWeek: "asc" }, { startTime: "asc" }],
      },
      createdAt: true,
      updatedAt: true,
    },
  });
}

// Executes the database operation for "get active doctor profile availability for one day".
async function getActiveDoctorProfileForDate(doctorId, dayOfWeek) {
  return prisma.doctorProfile.findFirst({
    where: { id: doctorId, isActive: true },
    select: {
      id: true,
      userId: true,
      availableTimes: {
        where: { dayOfWeek },
        select: selectAvailableTimeFields(),
        orderBy: [{ startTime: "asc" }],
      },
    },
  });
}

module.exports = {
  getActiveDoctorProfiles,
  getDoctorAvailableTimes,
  getDoctorProfileWithAvailability,
  getActiveDoctorProfileForDate,
};
