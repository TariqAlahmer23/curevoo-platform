// Handles admin doctor/patient management persistence.
const { prisma } = require("../../prisma/client");

const doctorUserSelect = {
  id: true,
  email: true,
  role: true,
  name: true,
  phoneNumber: true,
  age: true,
  isEmailVerified: true,
  createdAt: true,
  updatedAt: true,
  doctorProfile: {
    select: {
      id: true,
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
      isActive: true,
      qrCode: true,
      createdAt: true,
      updatedAt: true,
    },
  },
};

const patientUserSelect = {
  id: true,
  email: true,
  role: true,
  name: true,
  phoneNumber: true,
  age: true,
  isEmailVerified: true,
  createdAt: true,
  updatedAt: true,
  patientProfile: {
    select: {
      id: true,
      fullName: true,
      address: true,
      phoneNumber: true,
      age: true,
      sex: true,
      medicalHistory: true,
      riskFactors: true,
      qrCode: true,
      createdAt: true,
      updatedAt: true,
    },
  },
};

// Executes the database operation for "find doctor user by id".
function findDoctorUserById(userId) {
  return prisma.user.findFirst({
    where: { id: userId, role: "DOCTOR" },
    select: doctorUserSelect,
  });
}

// Executes the database operation for "find patient user by id".
function findPatientUserById(userId) {
  return prisma.user.findFirst({
    where: { id: userId, role: "PATIENT" },
    select: patientUserSelect,
  });
}

// Executes the database operation for "list doctor users".
function listDoctorUsers() {
  return prisma.user.findMany({
    where: { role: "DOCTOR" },
    orderBy: { createdAt: "desc" },
    select: doctorUserSelect,
  });
}

// Executes the database operation for "list patient users".
function listPatientUsers() {
  return prisma.user.findMany({
    where: { role: "PATIENT" },
    orderBy: { createdAt: "desc" },
    select: patientUserSelect,
  });
}

// Executes the database operation for "update doctor user and profile".
function updateDoctorUserById(userId, { userData, profileData }) {
  return prisma.$transaction(async (tx) => {
    if (Object.keys(userData).length) {
      await tx.user.update({
        where: { id: userId },
        data: userData,
      });
    }

    if (Object.keys(profileData).length) {
      await tx.doctorProfile.update({
        where: { userId },
        data: profileData,
      });
    }

    return tx.user.findFirst({
      where: { id: userId, role: "DOCTOR" },
      select: doctorUserSelect,
    });
  });
}

// Executes the database operation for "update patient user and profile".
function updatePatientUserById(userId, { userData, profileData }) {
  return prisma.$transaction(async (tx) => {
    if (Object.keys(userData).length) {
      await tx.user.update({
        where: { id: userId },
        data: userData,
      });
    }

    if (Object.keys(profileData).length) {
      await tx.patientProfile.update({
        where: { userId },
        data: profileData,
      });
    }

    return tx.user.findFirst({
      where: { id: userId, role: "PATIENT" },
      select: patientUserSelect,
    });
  });
}

// Executes the database operation for "delete user by id".
function deleteUserById(userId) {
  return prisma.user.delete({
    where: { id: userId },
    select: { id: true, role: true, email: true },
  });
}

module.exports = {
  findDoctorUserById,
  findPatientUserById,
  listDoctorUsers,
  listPatientUsers,
  updateDoctorUserById,
  updatePatientUserById,
  deleteUserById,
};
