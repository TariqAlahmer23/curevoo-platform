// Handles doctor availability slot and activation state persistence.
const prisma = require("../../prisma/client");

function selectAvailableTimeFields() {
  return {
    id: true,
    dayOfWeek: true,
    startTime: true,
    endTime: true,
    isOn: true,
    createdAt: true,
    updatedAt: true,
  };
}

async function findDoctorProfileByUserId(userId) {
  return prisma.doctorProfile.findUnique({
    where: { userId },
    select: {
      id: true,
      userId: true,
      isActive: true,
    },
  });
}

// Available Times
async function createAvailableTime(doctorId, data) {
  return prisma.doctorAvailableTime.create({
    data: {
      doctorId,
      dayOfWeek: data.dayOfWeek,
      startTime: data.startTime ?? null,
      endTime: data.endTime ?? null,
      isOn: data.isOn ?? true,
    },
    select: selectAvailableTimeFields(),
  });
}

// Executes the database operation for "get available times by doctor".
async function getAvailableTimesByDoctor(doctorId) {
  return prisma.doctorAvailableTime.findMany({
    where: { doctorId },
    select: selectAvailableTimeFields(),
    orderBy: [{ dayOfWeek: "asc" }, { startTime: "asc" }],
  });
}

// Executes the database operation for "get available time by id".
async function getAvailableTimeById(id, doctorId) {
  return prisma.doctorAvailableTime.findFirst({
    where: {
      id,
      doctorId,
    },
    select: selectAvailableTimeFields(),
  });
}

async function getAvailableTimeByDay(doctorId, dayOfWeek) {
  return prisma.doctorAvailableTime.findFirst({
    where: {
      doctorId,
      dayOfWeek,
    },
    select: selectAvailableTimeFields(),
  });
}

// Executes the database operation for "update available time".
async function updateAvailableTime(id, data) {
  return prisma.doctorAvailableTime.update({
    where: { id },
    data,
    select: selectAvailableTimeFields(),
  });
}

// Executes the database operation for "delete available times by day".
async function deleteAvailableTimesByDay(doctorId, dayOfWeek, excludeId = null) {
  return prisma.doctorAvailableTime.deleteMany({
    where: {
      doctorId,
      dayOfWeek,
      ...(excludeId ? { id: { not: excludeId } } : {}),
    },
  });
}

// Executes the database operation for "delete available time".
async function deleteAvailableTime(id) {
  return prisma.doctorAvailableTime.delete({
    where: { id },
  });
}

// Doctor Status
async function updateDoctorStatus(userId, isActive) {
  return prisma.doctorProfile.update({
    where: { userId },
    data: { isActive },
    select: {
      id: true,
      isActive: true,
      updatedAt: true,
    },
  });
}

// Executes the database operation for "get doctor status".
async function getDoctorStatus(userId) {
  return prisma.doctorProfile.findUnique({
    where: { userId },
    select: {
      isActive: true,
    },
  });
}

module.exports = {
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
};
