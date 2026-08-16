// Coordinates account creation, QR workflows, and doctor-patient connection logic.
const bcrypt = require("bcrypt");
const { AppError } = require("../../common/errors/AppError");
const {
  signAccessToken,
  signRefreshToken,
  decodeTokenClaims,
  generateTokenId,
} = require("../auth/token.service");
const { generateRoleQrCode, parseRoleQrCode } = require("../../common/utils/qrCode");
const repo = require("./registration.repo");
const patientsRepo = require("../patients/patients.repo");

const OTP_MAX_ATTEMPTS = Number(process.env.OTP_MAX_ATTEMPTS || 5);
const OTP_LOCK_MINUTES = Number(process.env.OTP_LOCK_MINUTES || 15);

// Generates a six-digit one-time password for verification flows.
function generateOtp() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function getTokenExpiresAt(token) {
  const claims = decodeTokenClaims(token);
  if (!claims?.exp) {
    throw new AppError("Unable to determine token expiry", 500, "TOKEN_EXP_PARSE_FAILED");
  }
  return new Date(claims.exp * 1000);
}

async function issueAuthTokensForUser(user, meta = {}) {
  const accessToken = signAccessToken({ userId: user.id, role: user.role });
  const refreshJti = generateTokenId();
  const refreshToken = signRefreshToken({
    userId: user.id,
    role: user.role,
    jti: refreshJti,
  });

  await repo.createRefreshTokenSession({
    userId: user.id,
    jti: refreshJti,
    expiresAt: getTokenExpiresAt(refreshToken),
    userAgent: meta.userAgent,
    ipAddress: meta.ipAddress,
  });

  return { accessToken, refreshToken };
}

// Returns the stored QR payload from the user doctor or patient profile.
function getUserQrString(user) {
  return user?.doctorProfile?.qrCode || user?.patientProfile?.qrCode || null;
}

// Executes the "create account" business workflow for this module.
async function createAccount(
  {
    email,
    password,
    fullName,
    role,
    phoneNumber,
    age,
    specialization,
    workingAt,
    experience,
    location,
    languages,
    photoUrl,
  },
  actor,
) {
  // The shared account endpoint can create admins only when an authenticated admin performs the action.
  if (role === "ADMIN" && (!actor || actor.role !== "ADMIN")) {
    throw new AppError(
      "Only admin can create an admin account",
      403,
      "ADMIN_REQUIRED",
    );
  }

  const existing = await repo.findUserByEmail(email);
  if (existing) throw new AppError("Email already in use", 409, "EMAIL_TAKEN");

  const passwordHash = await bcrypt.hash(password, 12);
  const user = await repo.createUserWithProfiles({
    email,
    passwordHash,
    role,
    fullName,
    phoneNumber,
    age,
    specialization,
    workingAt,
    experience,
    location,
    languages,
    photoUrl,
  });

  const { accessToken, refreshToken } = await issueAuthTokensForUser(user);

  return {
    user,
    accessToken,
    refreshToken,
    qrString: getUserQrString(user),
  };
}

// Executes the "login" business workflow for this module.
async function login({ email, password }) {
  const user = await repo.findUserByEmail(email);
  if (!user) throw new AppError("Invalid credentials", 401, "INVALID_CREDENTIALS");

  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) throw new AppError("Invalid credentials", 401, "INVALID_CREDENTIALS");

  const { accessToken, refreshToken } = await issueAuthTokensForUser(user);

  return {
    accessToken,
    refreshToken,
    user: {
      id: user.id,
      email: user.email,
      role: user.role,
      isEmailVerified: user.isEmailVerified,
    },
  };
}

// Executes the "send otp" business workflow for this module.
async function sendOtp({ email, purpose }) {
  const user = await repo.findUserByEmail(email);
  if (!user) throw new AppError("User not found", 404, "USER_NOT_FOUND");

  await repo.invalidateOldOtps({ userId: user.id, purpose });

  const otp = generateOtp();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
  const otpHash = await bcrypt.hash(otp, 12);
  await repo.createOtp({ userId: user.id, email, otpHash, purpose, expiresAt });

  return {
    sent: true,
    purpose,
    expiresAt,
  };
}

async function verifyOtpChallenge({ email, otp, purpose }) {
  const challenge = await repo.findLatestActiveOtp({ email, purpose });
  if (!challenge) {
    throw new AppError("Invalid or expired OTP", 400, "INVALID_OTP");
  }

  if (challenge.lockedUntil && challenge.lockedUntil > new Date()) {
    throw new AppError(
      "Too many failed OTP attempts. Please try again later.",
      429,
      "OTP_LOCKED",
    );
  }

  const isValid = await bcrypt.compare(otp, challenge.otpHash);
  if (!isValid) {
    const nextAttempts = challenge.attempts + 1;
    const lockUntil =
      nextAttempts >= OTP_MAX_ATTEMPTS
        ? new Date(Date.now() + OTP_LOCK_MINUTES * 60 * 1000)
        : null;

    await repo.registerFailedOtpAttempt(challenge.id, lockUntil);
    throw new AppError("Invalid or expired OTP", 400, "INVALID_OTP");
  }

  await repo.markOtpUsed(challenge.id);
  return challenge;
}

// Executes the "verify email otp" business workflow for this module.
async function verifyEmailOtp({ email, otp }) {
  const code = await verifyOtpChallenge({
    email,
    otp,
    purpose: "EMAIL_VERIFICATION",
  });
  const user = await repo.updateUserEmailVerified(code.userId);
  return user;
}

// Executes the "reset password with otp" business workflow for this module.
async function resetPasswordWithOtp({ email, otp, newPassword }) {
  const code = await verifyOtpChallenge({
    email,
    otp,
    purpose: "PASSWORD_RESET",
  });

  const passwordHash = await bcrypt.hash(newPassword, 12);
  await repo.updatePasswordByUserId(code.userId, passwordHash);
  await repo.revokeAllRefreshTokenSessionsForUser(code.userId, "PASSWORD_RESET");
  return { ok: true };
}

// Executes the authenticated "change password" business workflow for this module.
async function changePassword(userId, { currentPassword, newPassword }) {
  const user = await repo.findUserCredentialsById(userId);
  if (!user) throw new AppError("User not found", 404, "USER_NOT_FOUND");

  const currentPasswordMatches = await bcrypt.compare(
    currentPassword,
    user.passwordHash,
  );
  if (!currentPasswordMatches) {
    throw new AppError(
      "Current password is incorrect",
      400,
      "INVALID_CURRENT_PASSWORD",
    );
  }

  const passwordHash = await bcrypt.hash(newPassword, 12);
  await repo.updatePasswordByUserId(userId, passwordHash);
  await repo.revokeAllRefreshTokenSessionsForUser(userId, "PASSWORD_CHANGED");

  return { ok: true };
}

// Executes the "create patient by doctor" business workflow for this module.
async function createPatientByDoctor(doctorUserId, data) {
  const createdPatient = await patientsRepo.createCreatedPatient({
    doctorUserId,
    ...data,
  });

  return { createdPatient };
}

// Executes the "list doctor active patients" business workflow for this module.
async function listDoctorActivePatients(doctorUserId) {
  return repo.listDoctorActivePatients(doctorUserId);
}

// Executes the "list doctor created patients" business workflow for this module.
async function listDoctorCreatedPatients(doctorUserId) {
  return patientsRepo.listDoctorCreatedPatients(doctorUserId);
}

// Executes the "delete account requested by user" business workflow for this module.
async function deleteAccountRequestedByUser(userId) {
  const user = await repo.findUserById(userId);
  if (!user) throw new AppError("User not found", 404, "USER_NOT_FOUND");

  if (user.role !== "PATIENT") {
    await repo.deleteUserById(userId);
    return { deleted: true, pendingDoctorActions: 0 };
  }

  const links = await repo.listPatientLinksByPatient(userId);
  if (!links.length) {
    await repo.deleteUserById(userId);
    return { deleted: true, pendingDoctorActions: 0 };
  }

  // Patient deletion is deferred until every linked doctor handles the request.
  for (const link of links) {
    await repo.upsertPatientDeletionRequest({
      patientUserId: userId,
      doctorUserId: link.doctorUserId,
    });

    await repo.createNotification({
      userId: link.doctorUserId,
      title: "Patient requested account deletion",
      message:
        "A patient requested account deletion. Choose whether to keep data as created-patient.",
      payload: { patientUserId: userId },
    });
  }

  return { deleted: false, pendingDoctorActions: links.length };
}

// Executes the "list doctor deletion requests" business workflow for this module.
async function listDoctorDeletionRequests(doctorUserId) {
  return repo.listDoctorDeletionRequests(doctorUserId);
}

// Executes the "get my qr code" business workflow for this module.
async function getMyQrCode(userId) {
  const user = await repo.findUserById(userId);
  if (!user) throw new AppError("User not found", 404, "USER_NOT_FOUND");

  // Reuse the stored QR payload when available so clients can regenerate the image without extra state.
  if (user.role === "DOCTOR") {
    if (user.doctorProfile?.qrCode) {
      return {
        role: user.role,
        userId: user.id,
        qrCode: user.doctorProfile.qrCode,
        qrString: user.doctorProfile.qrCode,
      };
    }

    const qrCode = generateRoleQrCode("DOCTOR", user.id);
    const updated = await repo.updateDoctorQrCode(userId, qrCode);
    return {
      role: user.role,
      userId: user.id,
      qrCode: updated.qrCode,
      qrString: updated.qrCode,
    };
  }

  if (user.role === "PATIENT") {
    if (user.patientProfile?.qrCode) {
      return {
        role: user.role,
        userId: user.id,
        qrCode: user.patientProfile.qrCode,
        qrString: user.patientProfile.qrCode,
      };
    }

    const qrCode = generateRoleQrCode("PATIENT", user.id);
    const updated = await repo.updatePatientQrCode(userId, qrCode);
    return {
      role: user.role,
      userId: user.id,
      qrCode: updated.qrCode,
      qrString: updated.qrCode,
    };
  }

  throw new AppError("QR code is available only for doctor/patient", 400, "QR_NOT_SUPPORTED");
}

// Executes the "regenerate doctor qr code" business workflow for this module.
async function regenerateDoctorQrCode(doctorUserId) {
  const user = await repo.findUserById(doctorUserId);
  if (!user || user.role !== "DOCTOR") {
    throw new AppError("Doctor not found", 404, "DOCTOR_NOT_FOUND");
  }

  for (let attempt = 0; attempt < 5; attempt += 1) {
    const qrCode = generateRoleQrCode("DOCTOR", doctorUserId);
    try {
      const updated = await repo.updateDoctorQrCode(doctorUserId, qrCode);
      return {
        doctorUserId,
        qrCode: updated.qrCode,
        qrString: updated.qrCode,
      };
    } catch (error) {
      if (error?.code === "P2002") continue;
      throw error;
    }
  }

  throw new AppError(
    "Unable to regenerate QR code right now",
    500,
    "QR_REGENERATE_FAILED",
  );
}

// Executes the "scan doctor qr by patient" business workflow for this module.
async function scanDoctorQrByPatient(patientUserId, qrCode) {
  const patient = await repo.findUserById(patientUserId);
  if (!patient || patient.role !== "PATIENT") {
    throw new AppError("Patient not found", 404, "PATIENT_NOT_FOUND");
  }

  // New QR payloads embed the target user id, but older random-only payloads are still supported.
  const parsedQr = parseRoleQrCode(qrCode);
  let doctor = null;

  if (parsedQr?.role === "DOCTOR" && parsedQr.entityId) {
    doctor = await repo.findUserById(parsedQr.entityId);

    if (
      !doctor ||
      doctor.role !== "DOCTOR" ||
      doctor.doctorProfile?.qrCode !== qrCode
    ) {
      throw new AppError("Invalid doctor QR code", 400, "INVALID_DOCTOR_QR");
    }
  } else {
    doctor = await repo.findDoctorByQrCode(qrCode);
  }

  if (!doctor) {
    throw new AppError("Invalid doctor QR code", 400, "INVALID_DOCTOR_QR");
  }

  const existingLink = await repo.findActiveDoctorPatientLink({
    doctorUserId: doctor.id,
    patientUserId,
  });
  if (existingLink) {
    return {
      status: "ALREADY_LINKED",
      doctorUserId: doctor.id,
    };
  }

  const request = await repo.upsertDoctorConnectionRequest({
    doctorUserId: doctor.id,
    patientUserId,
  });

  return {
    status: "PENDING_APPROVAL",
    doctorUserId: doctor.id,
    request,
  };
}

// Executes the "scan patient qr by doctor" business workflow for this module.
async function scanPatientQrByDoctor(doctorUserId, qrCode) {
  const doctor = await repo.findUserById(doctorUserId);
  if (!doctor || doctor.role !== "DOCTOR") {
    throw new AppError("Doctor not found", 404, "DOCTOR_NOT_FOUND");
  }

  // The reverse scan path follows the same compatibility rule for older QR payloads.
  const parsedQr = parseRoleQrCode(qrCode);
  let patient = null;

  if (parsedQr?.role === "PATIENT" && parsedQr.entityId) {
    patient = await repo.findUserById(parsedQr.entityId);

    if (
      !patient ||
      patient.role !== "PATIENT" ||
      patient.patientProfile?.qrCode !== qrCode
    ) {
      throw new AppError("Invalid patient QR code", 400, "INVALID_PATIENT_QR");
    }
  } else {
    patient = await repo.findPatientByQrCode(qrCode);
  }

  if (!patient) {
    throw new AppError("Invalid patient QR code", 400, "INVALID_PATIENT_QR");
  }

  const link = await repo.createDoctorPatientLink({
    doctorUserId,
    patientUserId: patient.id,
    createdByDoctor: true,
  });

  await repo.markPendingConnectionRequestAcceptedByPair({
    doctorUserId,
    patientUserId: patient.id,
  });

  return {
    status: "LINKED",
    link,
  };
}

// Executes the "list doctor connection requests" business workflow for this module.
async function listDoctorConnectionRequests(doctorUserId) {
  return repo.listDoctorConnectionRequests(doctorUserId);
}

// Executes the "respond to connection request" business workflow for this module.
async function respondToConnectionRequest(doctorUserId, requestId, action) {
  const request = await repo.findDoctorConnectionRequestById(requestId);
  if (!request) {
    throw new AppError("Connection request not found", 404, "REQUEST_NOT_FOUND");
  }

  if (request.doctorUserId !== doctorUserId) {
    throw new AppError("Forbidden", 403, "FORBIDDEN");
  }

  if (request.status !== "PENDING") {
    throw new AppError(
      "Connection request already handled",
      400,
      "REQUEST_ALREADY_RESOLVED",
    );
  }

  if (action === "ACCEPT") {
    await repo.createDoctorPatientLink({
      doctorUserId,
      patientUserId: request.patientUserId,
      createdByDoctor: false,
    });
  }

  const status = action === "ACCEPT" ? "ACCEPTED" : "REJECTED";
  const updated = await repo.updateDoctorConnectionRequestStatus(
    requestId,
    status,
  );

  return {
    status: updated.status,
    requestId: updated.id,
  };
}

// Executes the "respond to deletion request" business workflow for this module.
async function respondToDeletionRequest(doctorUserId, requestId, action) {
  const request = await repo.findDeletionRequestById(requestId);
  if (!request) {
    throw new AppError("Deletion request not found", 404, "REQUEST_NOT_FOUND");
  }
  if (request.doctorUserId !== doctorUserId) {
    throw new AppError("Forbidden", 403, "FORBIDDEN");
  }
  if (request.status !== "PENDING") {
    throw new AppError(
      "Deletion request already handled",
      400,
      "REQUEST_ALREADY_RESOLVED",
    );
  }

  const patient = await repo.findUserById(request.patientUserId);
  if (!patient) {
    await repo.resolveDeletionRequest(requestId, "REMOVE_ONLY");
    return { status: "REMOVE_ONLY", deleted: true };
  }

  if (action === "KEEP_AS_CREATED_PATIENT") {
    await patientsRepo.createCreatedPatientFromProfile({
      doctorUserId,
      patientUserId: patient.id,
      profile: patient.patientProfile,
    });
  }

  await repo.resolveDeletionRequest(requestId, action);
  await repo.setDoctorPatientLinkInactive({
    doctorUserId,
    patientUserId: request.patientUserId,
  });

  const pending = await repo.listPendingDeletionRequestsForPatient(
    request.patientUserId,
  );

  let deleted = false;
  if (!pending.length) {
    try {
      await repo.deleteUserById(request.patientUserId);
      deleted = true;
    } catch {
      deleted = true;
    }
  }

  return { status: action, deleted };
}

// Executes the "list my notifications" business workflow for this module.
async function listMyNotifications(userId) {
  return repo.listNotificationsByUser(userId);
}

// Executes the "logout" business workflow for this module.
async function logout(userId) {
  if (userId) {
    await repo.revokeAllRefreshTokenSessionsForUser(userId, "GLOBAL_LOGOUT");
  }
  return { ok: true };
}

module.exports = {
  createAccount,
  login,
  sendOtp,
  verifyEmailOtp,
  resetPasswordWithOtp,
  changePassword,
  createPatientByDoctor,
  listDoctorActivePatients,
  listDoctorCreatedPatients,
  getMyQrCode,
  regenerateDoctorQrCode,
  scanDoctorQrByPatient,
  scanPatientQrByDoctor,
  listDoctorConnectionRequests,
  respondToConnectionRequest,
  deleteAccountRequestedByUser,
  listDoctorDeletionRequests,
  respondToDeletionRequest,
  listMyNotifications,
  logout,
};
