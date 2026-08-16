// Implements admin workflows for managing doctor and patient users.
const bcrypt = require("bcrypt");
const { AppError } = require("../../common/errors/AppError");
const registrationService = require("../registration/registration.service");
const repo = require("./admin-users.repo");

function isPrismaUniqueConstraintError(error) {
  return error?.code === "P2002";
}

function ensureNotSelfDelete(actorUserId, targetUserId) {
  if (actorUserId === targetUserId) {
    throw new AppError(
      "Admin cannot delete their own account from this endpoint",
      400,
      "ADMIN_SELF_DELETE_FORBIDDEN",
    );
  }
}

// Executes the "list all doctors for admin" workflow for this module.
async function listDoctorsByAdmin() {
  const items = await repo.listDoctorUsers();
  return { items };
}

// Executes the "list all patients for admin" workflow for this module.
async function listPatientsByAdmin() {
  const items = await repo.listPatientUsers();
  return { items };
}

// Executes the "create doctor by admin" workflow for this module.
async function createDoctorByAdmin(data, actor) {
  try {
    const result = await registrationService.createAccount(
      {
        ...data,
        role: "DOCTOR",
      },
      actor,
    );

    return result;
  } catch (error) {
    if (isPrismaUniqueConstraintError(error)) {
      throw new AppError("Email already in use", 409, "EMAIL_TAKEN");
    }
    throw error;
  }
}

// Executes the "create patient by admin" workflow for this module.
async function createPatientByAdmin(data, actor) {
  try {
    const result = await registrationService.createAccount(
      {
        ...data,
        role: "PATIENT",
      },
      actor,
    );

    return result;
  } catch (error) {
    if (isPrismaUniqueConstraintError(error)) {
      throw new AppError("Email already in use", 409, "EMAIL_TAKEN");
    }
    throw error;
  }
}

// Executes the "update doctor by admin" workflow for this module.
async function updateDoctorByAdmin(doctorUserId, data) {
  const existing = await repo.findDoctorUserById(doctorUserId);
  if (!existing) {
    throw new AppError("Doctor not found", 404, "DOCTOR_NOT_FOUND");
  }

  const userData = {};
  const profileData = {};

  if (data.email !== undefined) userData.email = data.email;
  if (data.password !== undefined) {
    userData.passwordHash = await bcrypt.hash(data.password, 12);
  }
  if (data.fullName !== undefined) {
    userData.name = data.fullName;
    profileData.fullName = data.fullName;
  }
  if (data.phoneNumber !== undefined) {
    userData.phoneNumber = data.phoneNumber;
  }
  if (data.age !== undefined) userData.age = data.age;

  if (data.specialization !== undefined) profileData.specialization = data.specialization;
  if (data.workingAt !== undefined) profileData.workingAt = data.workingAt;
  if (data.experience !== undefined) profileData.experience = data.experience;
  if (data.location !== undefined) profileData.location = data.location;
  if (data.languages !== undefined) profileData.languages = data.languages;
  if (data.photoUrl !== undefined) profileData.photoUrl = data.photoUrl;
  if (data.qualifications !== undefined) profileData.qualifications = data.qualifications;
  if (data.bio !== undefined) profileData.bio = data.bio;
  if (data.consultationFee !== undefined) profileData.consultationFee = data.consultationFee;
  if (data.isActive !== undefined) profileData.isActive = data.isActive;

  try {
    const updated = await repo.updateDoctorUserById(doctorUserId, {
      userData,
      profileData,
    });

    if (!updated) {
      throw new AppError("Doctor not found", 404, "DOCTOR_NOT_FOUND");
    }

    return updated;
  } catch (error) {
    if (isPrismaUniqueConstraintError(error)) {
      throw new AppError("Email already in use", 409, "EMAIL_TAKEN");
    }
    throw error;
  }
}

// Executes the "update patient by admin" workflow for this module.
async function updatePatientByAdmin(patientUserId, data) {
  const existing = await repo.findPatientUserById(patientUserId);
  if (!existing) {
    throw new AppError("Patient not found", 404, "PATIENT_NOT_FOUND");
  }

  const userData = {};
  const profileData = {};

  if (data.email !== undefined) userData.email = data.email;
  if (data.password !== undefined) {
    userData.passwordHash = await bcrypt.hash(data.password, 12);
  }
  if (data.fullName !== undefined) {
    userData.name = data.fullName;
    profileData.fullName = data.fullName;
  }
  if (data.phoneNumber !== undefined) {
    userData.phoneNumber = data.phoneNumber;
    profileData.phoneNumber = data.phoneNumber;
  }
  if (data.age !== undefined) {
    userData.age = data.age;
    profileData.age = data.age;
  }
  if (data.sex !== undefined) profileData.sex = data.sex;
  if (data.address !== undefined) profileData.address = data.address;
  if (data.medicalHistory !== undefined) profileData.medicalHistory = data.medicalHistory;
  if (data.riskFactors !== undefined) profileData.riskFactors = data.riskFactors;

  try {
    const updated = await repo.updatePatientUserById(patientUserId, {
      userData,
      profileData,
    });

    if (!updated) {
      throw new AppError("Patient not found", 404, "PATIENT_NOT_FOUND");
    }

    return updated;
  } catch (error) {
    if (isPrismaUniqueConstraintError(error)) {
      throw new AppError("Email already in use", 409, "EMAIL_TAKEN");
    }
    throw error;
  }
}

// Executes the "delete doctor by admin" workflow for this module.
async function deleteDoctorByAdmin(actorUserId, doctorUserId) {
  ensureNotSelfDelete(actorUserId, doctorUserId);

  const existing = await repo.findDoctorUserById(doctorUserId);
  if (!existing) {
    throw new AppError("Doctor not found", 404, "DOCTOR_NOT_FOUND");
  }

  await repo.deleteUserById(doctorUserId);
  return { deleted: true, userId: doctorUserId, role: "DOCTOR" };
}

// Executes the "delete patient by admin" workflow for this module.
async function deletePatientByAdmin(actorUserId, patientUserId) {
  ensureNotSelfDelete(actorUserId, patientUserId);

  const existing = await repo.findPatientUserById(patientUserId);
  if (!existing) {
    throw new AppError("Patient not found", 404, "PATIENT_NOT_FOUND");
  }

  await repo.deleteUserById(patientUserId);
  return { deleted: true, userId: patientUserId, role: "PATIENT" };
}

module.exports = {
  listDoctorsByAdmin,
  listPatientsByAdmin,
  createDoctorByAdmin,
  createPatientByAdmin,
  updateDoctorByAdmin,
  updatePatientByAdmin,
  deleteDoctorByAdmin,
  deletePatientByAdmin,
};
