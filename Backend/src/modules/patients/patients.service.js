// Implements patient-facing account, profile, appointment, and created-patient workflows.
const { AppError } = require("../../common/errors/AppError");
const repo = require("./patients.repo");
const authService = require("../auth/auth.service");
const registrationService = require("../registration/registration.service");
const appointmentService = require("../appointments/appointments.service");

// Shapes patient profile data before returning it to patient clients.
function formatPatientProfile(profile) {
  if (!profile) return profile;

  return {
    id: profile.id,
    profileId: profile.id,
    userId: profile.userId,
    email: profile.user?.email || null,
    phoneNumber: profile.user?.phoneNumber || profile.phoneNumber || null,
    role: profile.user?.role || "PATIENT",
    name: profile.fullName || profile.user?.name || null,
    fullName: profile.fullName || profile.user?.name || null,
    location: profile.address || null,
    address: profile.address || null,
    age: profile.age ?? profile.user?.age ?? null,
    sex: profile.sex || null,
    medicalHistory: profile.medicalHistory || null,
    riskFactors: profile.riskFactors ?? null,
    qrCode: profile.qrCode || null,
    createdAt: profile.createdAt,
    updatedAt: profile.updatedAt,
    user: profile.user
      ? {
          id: profile.user.id,
          email: profile.user.email,
          role: profile.user.role,
          name: profile.user.name || null,
          phoneNumber: profile.user.phoneNumber || profile.phoneNumber || null,
          age: profile.user.age ?? null,
        }
      : null,
  };
}

// Executes the "register patient" business workflow for this module.
async function registerPatient(data) {
  return authService.registerPatient(data);
}

// Executes the "patient login" business workflow for this module.
async function login(data) {
  return authService.login(data);
}

// Executes the "patient refresh token" business workflow for this module.
async function refresh(refreshToken, meta) {
  return authService.refresh(refreshToken, meta);
}

// Executes the "patient forgot password send otp" business workflow for this module.
async function forgotPasswordSendOtp(data) {
  return registrationService.sendOtp({
    ...data,
    purpose: "PASSWORD_RESET",
  });
}

// Executes the "patient reset password" business workflow for this module.
async function resetPassword(data) {
  return registrationService.resetPasswordWithOtp(data);
}

// Executes the authenticated "patient change password" business workflow for this module.
async function changePassword(userId, data) {
  return registrationService.changePassword(userId, data);
}

// Executes the "patient validate token" business workflow for this module.
async function validateToken(user) {
  return {
    valid: true,
    user: {
      id: user.sub,
      role: user.role,
    },
  };
}

// Executes the "patient logout" business workflow for this module.
async function logout(userId, refreshToken) {
  await authService.revokeRefreshTokenByToken(refreshToken, "LOGOUT");
  return registrationService.logout(userId);
}

// Executes the "get me" business workflow for this module.
async function getMe(userId) {
  const me = await repo.getPatientMe(userId);
  if (!me) {
    throw new AppError("Patient profile not found", 404, "PATIENT_NOT_FOUND");
  }
  return formatPatientProfile(me);
}

// Executes the "update me" business workflow for this module.
async function updateMe(userId, data) {
  await getMe(userId);
  const updated = await repo.updatePatientMe(userId, data);
  return formatPatientProfile(updated);
}

// Executes the "book appointment" business workflow for this module.
async function bookAppointment(userId, data) {
  await getMe(userId);
  return appointmentService.bookAppointment(userId, data);
}

// Executes the "view appointments" business workflow for this module.
async function viewAppointments(userId) {
  await getMe(userId);
  return appointmentService.viewAppointments(userId);
}

// Executes the "edit appointment" business workflow for this module.
async function editAppointment(userId, appointmentId, data) {
  await getMe(userId);
  return appointmentService.editAppointment(userId, appointmentId, data);
}

// Executes the "cancel appointment" business workflow for this module.
async function cancelAppointment(userId, appointmentId) {
  await getMe(userId);
  return appointmentService.cancelAppointment(userId, appointmentId);
}

// Executes the "delete appointment" business workflow for this module.
async function deleteAppointment(userId, appointmentId) {
  await getMe(userId);
  return appointmentService.deleteAppointment(userId, appointmentId);
}

// Executes the "create created patient by doctor" business workflow for this module.
async function createCreatedPatientByDoctor(doctorUserId, data) {
  const createdPatient = await repo.createCreatedPatient({
    doctorUserId,
    ...data,
  });

  return { createdPatient };
}

// Executes the "list doctor created patients" business workflow for this module.
async function listDoctorCreatedPatients(doctorUserId) {
  return repo.listDoctorCreatedPatients(doctorUserId);
}

// Executes the "create created patient snapshot" business workflow for this module.
async function createCreatedPatientSnapshot(doctorUserId, patientUserId, profile) {
  return repo.createCreatedPatientFromProfile({
    doctorUserId,
    patientUserId,
    profile,
  });
}

// Retained for the deferred AI cancer detector flow.
async function uploadTestRecord(userId, data) {
  await getMe(userId);
  return repo.createTestRecordWithResistance(userId, data);
}

// Retained for the deferred AI cancer detector flow.
async function viewAIResults(userId) {
  await getMe(userId);
  return repo.listPatientAiResults(userId);
}

// Executes the "get patient dashboard summary" business workflow for this module.
async function getDashboardSummary(userId) {
  await getMe(userId);

  const [upcomingAppointments, latestNsclcPrediction] = await Promise.all([
    repo.countUpcomingAppointmentsForPatient(userId),
    repo.getLatestSuccessfulNsclcPredictionForPatient(userId),
  ]);

  return {
    upcomingAppointments,
    latestAiResult: latestNsclcPrediction
      ? {
          predictionRunId: latestNsclcPrediction.id,
          predictionVersion: latestNsclcPrediction.predictionVersion,
          summaryText: latestNsclcPrediction.summaryText,
          earlyFailureProbability: latestNsclcPrediction.earlyFailureProbability,
          earlyFailureRiskLevel: latestNsclcPrediction.earlyFailureRiskLevel,
          durableBenefitProbability: latestNsclcPrediction.durableBenefitProbability,
          durableBenefitRiskLevel: latestNsclcPrediction.durableBenefitRiskLevel,
          interpretationSummary: latestNsclcPrediction.interpretationSummary,
          createdAt: latestNsclcPrediction.createdAt,
        }
      : null,
  };
}

module.exports = {
  registerPatient,
  login,
  refresh,
  forgotPasswordSendOtp,
  resetPassword,
  changePassword,
  validateToken,
  logout,
  getMe,
  updateMe,
  bookAppointment,
  viewAppointments,
  editAppointment,
  cancelAppointment,
  deleteAppointment,
  createCreatedPatientByDoctor,
  listDoctorCreatedPatients,
  createCreatedPatientSnapshot,
  uploadTestRecord,
  viewAIResults,
  getDashboardSummary,
};
