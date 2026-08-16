// Handles registration, QR, notifications, and doctor-patient link persistence.
const { prisma } = require("../../prisma/client");
const { generateRoleQrCode } = require("../../common/utils/qrCode");

const userWithProfilesSelect = {
  id: true,
  email: true,
  role: true,
  name: true,
  phoneNumber: true,
  age: true,
  isEmailVerified: true,
  createdAt: true,
  patientProfile: {
    select: {
      id: true,
      fullName: true,
      age: true,
      qrCode: true,
    },
  },
  doctorProfile: {
    select: {
      id: true,
      userId: true,
      fullName: true,
      specialization: true,
      workingAt: true,
      languages: true,
      location: true,
      experience: true,
      photoUrl: true,
      qrCode: true,
    },
  },
};

// Executes the database operation for "find user by email".
function findUserByEmail(email) {
  return prisma.user.findUnique({ where: { email } });
}

// Executes the database operation for "find user by id".
function findUserById(id) {
  return prisma.user.findUnique({
    where: { id },
    include: {
      patientProfile: true,
      doctorProfile: true,
    },
  });
}

// Executes the database operation for "create user with profiles".
function createUserWithProfiles({
  email,
  passwordHash,
  role,
  fullName,
  phoneNumber,
  age,
  specialization,
  workingAt,
  languages,
  location,
  experience,
  photoUrl,
  generateQrCode = true,
}) {
  const isPatient = role === "PATIENT";
  const isDoctor = role === "DOCTOR";

  return prisma.$transaction(async (tx) => {
    const createdUser = await tx.user.create({
      data: {
        email,
        passwordHash,
        role,
        name: fullName || null,
        phoneNumber: phoneNumber || null,
        age: age ?? null,
        patientProfile: isPatient
          ? {
              create: {
                fullName: fullName || null,
              },
            }
          : undefined,
        doctorProfile: isDoctor
          ? {
              create: {
                fullName: fullName || null,
                specialization: specialization || null,
                workingAt: workingAt || null,
                languages: languages?.length ? languages : undefined,
                location: location || null,
                experience: experience ?? null,
                photoUrl: photoUrl || null,
              },
            }
          : undefined,
        doctorSettings: isDoctor
          ? {
              create: {
                language: "en",
                notificationsEnabled: true,
              },
            }
          : undefined,
      },
      select: {
        id: true,
        role: true,
      },
    });

    if (generateQrCode && (role === "PATIENT" || role === "DOCTOR")) {
      const qrCode = generateRoleQrCode(role, createdUser.id);

      if (role === "PATIENT") {
        await tx.patientProfile.update({
          where: { userId: createdUser.id },
          data: { qrCode },
        });
      } else {
        await tx.doctorProfile.update({
          where: { userId: createdUser.id },
          data: { qrCode },
        });
      }
    }

    return tx.user.findUnique({
      where: { id: createdUser.id },
      select: userWithProfilesSelect,
    });
  });
}

// Executes the database operation for "update user email verified".
function updateUserEmailVerified(userId) {
  return prisma.user.update({
    where: { id: userId },
    data: { isEmailVerified: true },
    select: { id: true, email: true, role: true, isEmailVerified: true },
  });
}

// Executes the database operation for "update password by user id".
function updatePasswordByUserId(userId, passwordHash) {
  return prisma.user.update({
    where: { id: userId },
    data: { passwordHash },
    select: { id: true },
  });
}

// Executes the database operation for "create otp".
function createOtp({ userId, email, otpHash, purpose, expiresAt }) {
  return prisma.otpCode.create({
    data: { userId, email, otpHash, purpose, expiresAt },
  });
}

// Executes the database operation for "invalidate old otps".
function invalidateOldOtps({ userId, purpose }) {
  return prisma.otpCode.updateMany({
    where: {
      userId,
      purpose,
      usedAt: null,
    },
    data: { usedAt: new Date() },
  });
}

// Executes the database operation for "find latest active otp challenge".
function findLatestActiveOtp({ email, purpose }) {
  return prisma.otpCode.findFirst({
    where: {
      email,
      purpose,
      usedAt: null,
      expiresAt: { gt: new Date() },
    },
    orderBy: { createdAt: "desc" },
  });
}

// Executes the database operation for "register failed otp attempt and optional lock".
function registerFailedOtpAttempt(id, lockUntil) {
  return prisma.otpCode.update({
    where: { id },
    data: {
      attempts: { increment: 1 },
      lockedUntil: lockUntil ?? undefined,
    },
    select: {
      id: true,
      attempts: true,
      lockedUntil: true,
    },
  });
}

// Executes the database operation for "mark otp used".
function markOtpUsed(id) {
  return prisma.otpCode.update({
    where: { id },
    data: { usedAt: new Date(), attempts: 0, lockedUntil: null },
  });
}

// Executes the database operation for "create refresh token session".
function createRefreshTokenSession({
  userId,
  jti,
  expiresAt,
  userAgent,
  ipAddress,
}) {
  return prisma.refreshTokenSession.create({
    data: {
      userId,
      jti,
      expiresAt,
      userAgent: userAgent || null,
      ipAddress: ipAddress || null,
    },
  });
}

// Executes the database operation for "find refresh token session by jti".
function findRefreshTokenSessionByJti(jti) {
  return prisma.refreshTokenSession.findUnique({
    where: { jti },
  });
}

// Executes the database operation for "revoke refresh token session by jti".
function revokeRefreshTokenSessionByJti(jti, { replacedByJti, revokeReason }) {
  return prisma.refreshTokenSession.updateMany({
    where: {
      jti,
      revokedAt: null,
    },
    data: {
      revokedAt: new Date(),
      replacedByJti: replacedByJti ?? null,
      revokeReason: revokeReason ?? null,
    },
  });
}

// Executes the database operation for "revoke all active refresh token sessions for user".
function revokeAllRefreshTokenSessionsForUser(userId, revokeReason) {
  return prisma.refreshTokenSession.updateMany({
    where: {
      userId,
      revokedAt: null,
      expiresAt: { gt: new Date() },
    },
    data: {
      revokedAt: new Date(),
      revokeReason: revokeReason ?? "GLOBAL_LOGOUT",
    },
  });
}

// Executes the database operation for "create doctor patient link".
function createDoctorPatientLink({ doctorUserId, patientUserId, createdByDoctor }) {
  return prisma.doctorPatientLink.upsert({
    where: {
      doctorUserId_patientUserId: { doctorUserId, patientUserId },
    },
    create: {
      doctorUserId,
      patientUserId,
      createdByDoctor: !!createdByDoctor,
      status: "ACTIVE",
    },
    update: {
      status: "ACTIVE",
      createdByDoctor: createdByDoctor ? true : undefined,
    },
  });
}

// Executes the database operation for "find active doctor patient link".
function findActiveDoctorPatientLink({ doctorUserId, patientUserId }) {
  return prisma.doctorPatientLink.findFirst({
    where: { doctorUserId, patientUserId, status: "ACTIVE" },
  });
}

// Executes the database operation for "find doctor by qr code".
function findDoctorByQrCode(qrCode) {
  return prisma.user.findFirst({
    where: {
      role: "DOCTOR",
      doctorProfile: {
        is: { qrCode },
      },
    },
    select: {
      id: true,
      role: true,
      email: true,
      doctorProfile: {
        select: {
          id: true,
          fullName: true,
          qrCode: true,
        },
      },
    },
  });
}

// Executes the database operation for "find patient by qr code".
function findPatientByQrCode(qrCode) {
  return prisma.user.findFirst({
    where: {
      role: "PATIENT",
      patientProfile: {
        is: { qrCode },
      },
    },
    select: {
      id: true,
      role: true,
      email: true,
      patientProfile: {
        select: {
          id: true,
          fullName: true,
          qrCode: true,
        },
      },
    },
  });
}

// Executes the database operation for "upsert doctor connection request".
function upsertDoctorConnectionRequest({ doctorUserId, patientUserId }) {
  return prisma.doctorConnectionRequest.upsert({
    where: {
      doctorUserId_patientUserId: { doctorUserId, patientUserId },
    },
    create: {
      doctorUserId,
      patientUserId,
      status: "PENDING",
    },
    update: {
      status: "PENDING",
      respondedAt: null,
    },
    include: {
      doctor: {
        select: {
          id: true,
          email: true,
          doctorProfile: { select: { fullName: true } },
        },
      },
      patient: {
        select: {
          id: true,
          email: true,
          patientProfile: { select: { fullName: true } },
        },
      },
    },
  });
}

// Executes the database operation for "list doctor connection requests".
function listDoctorConnectionRequests(doctorUserId) {
  return prisma.doctorConnectionRequest.findMany({
    where: { doctorUserId },
    orderBy: { updatedAt: "desc" },
    include: {
      patient: {
        select: {
          id: true,
          email: true,
          patientProfile: { select: { fullName: true } },
        },
      },
    },
  });
}

// Executes the database operation for "find doctor connection request by id".
function findDoctorConnectionRequestById(id) {
  return prisma.doctorConnectionRequest.findUnique({
    where: { id },
  });
}

// Executes the database operation for "update doctor connection request status".
function updateDoctorConnectionRequestStatus(id, status) {
  return prisma.doctorConnectionRequest.update({
    where: { id },
    data: {
      status,
      respondedAt: new Date(),
    },
  });
}

// Executes the database operation for "mark pending connection request accepted by pair".
function markPendingConnectionRequestAcceptedByPair({ doctorUserId, patientUserId }) {
  return prisma.doctorConnectionRequest.updateMany({
    where: {
      doctorUserId,
      patientUserId,
      status: "PENDING",
    },
    data: {
      status: "ACCEPTED",
      respondedAt: new Date(),
    },
  });
}

// Executes the database operation for "list doctor active patients".
function listDoctorActivePatients(doctorUserId) {
  return prisma.doctorPatientLink.findMany({
    where: { doctorUserId, status: "ACTIVE" },
    orderBy: { createdAt: "desc" },
    include: {
      patient: {
        select: {
          id: true,
          email: true,
          patientProfile: {
            select: {
              fullName: true,
              age: true,
              sex: true,
              medicalHistory: true,
              riskFactors: true,
            },
          },
        },
      },
    },
  });
}

// Executes the database operation for "create created patient".
function createCreatedPatient({
  doctorUserId,
  fullName,
  phoneNumber,
  age,
  sex,
  medicalHistory,
  riskFactors,
}) {
  return prisma.createdPatient.create({
    data: {
      doctorUserId,
      fullName: fullName ?? null,
      phoneNumber: phoneNumber ?? null,
      age: age ?? null,
      sex: sex ?? null,
      medicalHistory: medicalHistory ?? null,
      riskFactors: riskFactors ?? null,
    },
  });
}

// Executes the database operation for "find user credentials by id".
function findUserCredentialsById(id) {
  return prisma.user.findUnique({
    where: { id },
    select: {
      id: true,
      passwordHash: true,
    },
  });
}

// Executes the database operation for "list doctor created patients".
function listDoctorCreatedPatients(doctorUserId) {
  return prisma.createdPatient.findMany({
    where: { doctorUserId },
    orderBy: { createdAt: "desc" },
  });
}

// Executes the database operation for "list patient links by patient".
function listPatientLinksByPatient(patientUserId) {
  return prisma.doctorPatientLink.findMany({
    where: { patientUserId, status: "ACTIVE" },
  });
}

// Executes the database operation for "upsert patient deletion request".
function upsertPatientDeletionRequest({ patientUserId, doctorUserId }) {
  return prisma.patientDeletionRequest.upsert({
    where: {
      patientUserId_doctorUserId: { patientUserId, doctorUserId },
    },
    create: {
      patientUserId,
      doctorUserId,
      status: "PENDING",
    },
    update: {
      status: "PENDING",
      resolvedAt: null,
    },
  });
}

// Executes the database operation for "create notification".
function createNotification({ userId, title, message, payload }) {
  return prisma.notification.create({
    data: {
      userId,
      type: "PATIENT_DELETE_REQUEST",
      title,
      message,
      payload,
    },
  });
}

// Executes the database operation for "list doctor deletion requests".
function listDoctorDeletionRequests(doctorUserId) {
  return prisma.patientDeletionRequest.findMany({
    where: { doctorUserId },
    orderBy: { createdAt: "desc" },
    include: {
      patient: {
        select: {
          id: true,
          email: true,
          patientProfile: { select: { fullName: true } },
        },
      },
    },
  });
}

// Executes the database operation for "find deletion request by id".
function findDeletionRequestById(id) {
  return prisma.patientDeletionRequest.findUnique({
    where: { id },
  });
}

// Executes the database operation for "resolve deletion request".
function resolveDeletionRequest(id, status) {
  return prisma.patientDeletionRequest.update({
    where: { id },
    data: {
      status,
      resolvedAt: new Date(),
    },
  });
}

// Executes the database operation for "list pending deletion requests for patient".
function listPendingDeletionRequestsForPatient(patientUserId) {
  return prisma.patientDeletionRequest.findMany({
    where: { patientUserId, status: "PENDING" },
  });
}

// Executes the database operation for "create created patient from profile".
function createCreatedPatientFromProfile({ doctorUserId, patientUserId, profile }) {
  return prisma.createdPatient.upsert({
    where: {
      doctorUserId_sourcePatientUserId: {
        doctorUserId,
        sourcePatientUserId: patientUserId,
      },
    },
    create: {
      doctorUserId,
      sourcePatientUserId: patientUserId,
      fullName: profile?.fullName || null,
      phoneNumber: profile?.phoneNumber || null,
      age: profile?.age || null,
      sex: profile?.sex || null,
      medicalHistory: profile?.medicalHistory || null,
      riskFactors: profile?.riskFactors || null,
    },
    update: {
      fullName: profile?.fullName || null,
      phoneNumber: profile?.phoneNumber || null,
      age: profile?.age || null,
      sex: profile?.sex || null,
      medicalHistory: profile?.medicalHistory || null,
      riskFactors: profile?.riskFactors || null,
    },
  });
}

// Executes the database operation for "set doctor patient link inactive".
function setDoctorPatientLinkInactive({ doctorUserId, patientUserId }) {
  return prisma.doctorPatientLink.updateMany({
    where: { doctorUserId, patientUserId },
    data: { status: "INACTIVE" },
  });
}

// Executes the database operation for "delete user by id".
function deleteUserById(id) {
  return prisma.user.delete({
    where: { id },
  });
}

// Executes the database operation for "list notifications by user".
function listNotificationsByUser(userId) {
  return prisma.notification.findMany({
    where: { userId },
    orderBy: { createdAt: "desc" },
  });
}

// Executes the database operation for "update doctor qr code".
function updateDoctorQrCode(userId, qrCode) {
  return prisma.doctorProfile.update({
    where: { userId },
    data: { qrCode },
    select: { qrCode: true },
  });
}

// Executes the database operation for "update patient qr code".
function updatePatientQrCode(userId, qrCode) {
  return prisma.patientProfile.update({
    where: { userId },
    data: { qrCode },
    select: { qrCode: true },
  });
}

module.exports = {
  findUserByEmail,
  findUserById,
  findUserCredentialsById,
  createUserWithProfiles,
  updateUserEmailVerified,
  updatePasswordByUserId,
  createOtp,
  invalidateOldOtps,
  findLatestActiveOtp,
  registerFailedOtpAttempt,
  markOtpUsed,
  createRefreshTokenSession,
  findRefreshTokenSessionByJti,
  revokeRefreshTokenSessionByJti,
  revokeAllRefreshTokenSessionsForUser,
  createDoctorPatientLink,
  findActiveDoctorPatientLink,
  findDoctorByQrCode,
  findPatientByQrCode,
  upsertDoctorConnectionRequest,
  listDoctorConnectionRequests,
  findDoctorConnectionRequestById,
  updateDoctorConnectionRequestStatus,
  markPendingConnectionRequestAcceptedByPair,
  listDoctorActivePatients,
  createCreatedPatient,
  listDoctorCreatedPatients,
  listPatientLinksByPatient,
  upsertPatientDeletionRequest,
  createNotification,
  listDoctorDeletionRequests,
  findDeletionRequestById,
  resolveDeletionRequest,
  listPendingDeletionRequestsForPatient,
  createCreatedPatientFromProfile,
  setDoctorPatientLinkInactive,
  deleteUserById,
  listNotificationsByUser,
  updateDoctorQrCode,
  updatePatientQrCode,
};
