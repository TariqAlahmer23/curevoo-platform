// Maps registration and QR workflow requests to the registration service layer.
const { asyncHandler } = require("../../common/utils/asyncHandler");
const { AppError } = require("../../common/errors/AppError");
const service = require("./registration.service");
const authService = require("../auth/auth.service");
const patientsService = require("../patients/patients.service");
const {
  createAccountSchema,
  loginSchema,
  sendOtpSchema,
  verifyOtpSchema,
  resetPasswordSchema,
  changePasswordSchema,
  respondDeletionRequestSchema,
  scanQrSchema,
  respondConnectionRequestSchema,
} = require("./registration.validation");
const { createCreatedPatientSchema } = require("../patients/patients.validation");
const {
  buildDoctorPhotoUrl,
  getUploadedDoctorPhoto,
  removeUploadedFile,
  validateDoctorPhotoFile,
} = require("../../common/utils/doctorPhoto");
const {
  setRefreshTokenCookie,
  clearRefreshTokenCookie,
  getRefreshTokenFromRequest,
} = require("../auth/token.service");

// Handles the "create account" endpoint and returns the service response.
const createAccount = asyncHandler(async (req, res) => {
  const photoFile = getUploadedDoctorPhoto(req);

  try {
    const data = createAccountSchema.parse(req.body);

    if (photoFile && data.role !== "DOCTOR") {
      throw new AppError(
        "Photo upload is available only for doctor registration",
        400,
        "PHOTO_DOCTOR_ONLY",
      );
    }

    if (photoFile) validateDoctorPhotoFile(photoFile);

    const actor = req.user ? { id: req.user.sub, role: req.user.role } : null;
    const result = await service.createAccount(
      {
        ...data,
        photoUrl: photoFile ? buildDoctorPhotoUrl(photoFile) : undefined,
      },
      actor,
    );

    setRefreshTokenCookie(res, result.refreshToken);
    res.status(201).json({ ok: true, data: result });
  } catch (error) {
    if (photoFile) removeUploadedFile(photoFile);
    throw error;
  }
});

// Handles the "login" endpoint and returns the service response.
const login = asyncHandler(async (req, res) => {
  const data = loginSchema.parse(req.body);
  const result = await service.login(data);
  setRefreshTokenCookie(res, result.refreshToken);
  res.json({ ok: true, data: result });
});

// Handles the "refresh" endpoint and returns the service response.
const refresh = asyncHandler(async (req, res) => {
  const token = getRefreshTokenFromRequest(req);
  if (!token)
    throw new AppError("Missing refresh token", 401, "NO_REFRESH_TOKEN");

  const result = await authService.refresh(token, {
    ipAddress: req.ip,
    userAgent: req.get("user-agent") || null,
  });
  setRefreshTokenCookie(res, result.refreshToken);
  res.json({ ok: true, data: { accessToken: result.accessToken } });
});

// Handles the "send otp" endpoint and returns the service response.
const sendOtp = asyncHandler(async (req, res) => {
  const data = sendOtpSchema.parse({
    ...req.body,
    purpose: "EMAIL_VERIFICATION",
  });
  const result = await service.sendOtp(data);
  res.json({ ok: true, data: result });
});

// Handles the "verify email otp" endpoint and returns the service response.
const verifyEmailOtp = asyncHandler(async (req, res) => {
  const data = verifyOtpSchema.parse({
    ...req.body,
    purpose: "EMAIL_VERIFICATION",
  });
  const result = await service.verifyEmailOtp(data);
  res.json({ ok: true, data: result });
});

// Handles the "forgot password send otp" endpoint and returns the service response.
const forgotPasswordSendOtp = asyncHandler(async (req, res) => {
  const data = sendOtpSchema.parse({
    ...req.body,
    purpose: "PASSWORD_RESET",
  });
  const result = await service.sendOtp(data);
  res.json({ ok: true, data: result });
});

// Handles the "reset password" endpoint and returns the service response.
const resetPassword = asyncHandler(async (req, res) => {
  const data = resetPasswordSchema.parse(req.body);
  const result = await service.resetPasswordWithOtp(data);
  res.json({ ok: true, data: result });
});

// Handles the authenticated "change password" endpoint and returns the service response.
const changePassword = asyncHandler(async (req, res) => {
  const data = changePasswordSchema.parse(req.body);
  const result = await service.changePassword(req.user.sub, data);
  res.json({ ok: true, data: result });
});

// Handles the "delete account" endpoint and returns the service response.
const deleteAccount = asyncHandler(async (req, res) => {
  const result = await service.deleteAccountRequestedByUser(req.user.sub);
  res.json({ ok: true, data: result });
});

// Handles the "logout" endpoint and returns the service response.
const logout = asyncHandler(async (req, res) => {
  const token = getRefreshTokenFromRequest(req);
  await authService.revokeRefreshTokenByToken(token, "LOGOUT");
  const result = await service.logout(req.user?.sub);
  clearRefreshTokenCookie(res);
  res.json({ ok: true, data: result });
});

// Handles the "create patient by doctor" endpoint and returns the service response.
const createPatientByDoctor = asyncHandler(async (req, res) => {
  const data = createCreatedPatientSchema.parse(req.body);
  const result = await patientsService.createCreatedPatientByDoctor(
    req.user.sub,
    data,
  );
  res.status(201).json({ ok: true, data: result });
});

// Handles the "get my qr code" endpoint and returns the service response.
const getMyQrCode = asyncHandler(async (req, res) => {
  const result = await service.getMyQrCode(req.user.sub);
  res.json({ ok: true, data: result });
});

// Handles the "regenerate doctor qr code" endpoint and returns the service response.
const regenerateDoctorQrCode = asyncHandler(async (req, res) => {
  const result = await service.regenerateDoctorQrCode(req.user.sub);
  res.json({ ok: true, data: result });
});

// Handles the "scan doctor qr" endpoint and returns the service response.
const scanDoctorQr = asyncHandler(async (req, res) => {
  const { qrCode } = scanQrSchema.parse(req.body);
  const result = await service.scanDoctorQrByPatient(req.user.sub, qrCode);
  res.json({ ok: true, data: result });
});

// Handles the "scan patient qr" endpoint and returns the service response.
const scanPatientQr = asyncHandler(async (req, res) => {
  const { qrCode } = scanQrSchema.parse(req.body);
  const result = await service.scanPatientQrByDoctor(req.user.sub, qrCode);
  res.json({ ok: true, data: result });
});

// Handles the "get doctor connection requests" endpoint and returns the service response.
const getDoctorConnectionRequests = asyncHandler(async (req, res) => {
  const result = await service.listDoctorConnectionRequests(req.user.sub);
  res.json({ ok: true, data: result });
});

// Handles the "respond to connection request" endpoint and returns the service response.
const respondToConnectionRequest = asyncHandler(async (req, res) => {
  const { action } = respondConnectionRequestSchema.parse(req.body);
  const result = await service.respondToConnectionRequest(
    req.user.sub,
    req.params.requestId,
    action,
  );
  res.json({ ok: true, data: result });
});

// Handles the "get doctor active patients" endpoint and returns the service response.
const getDoctorActivePatients = asyncHandler(async (req, res) => {
  const result = await service.listDoctorActivePatients(req.user.sub);
  res.json({ ok: true, data: result });
});

// Handles the "get doctor created patients" endpoint and returns the service response.
const getDoctorCreatedPatients = asyncHandler(async (req, res) => {
  const result = await patientsService.listDoctorCreatedPatients(req.user.sub);
  res.json({ ok: true, data: result });
});

// Handles the "get doctor deletion requests" endpoint and returns the service response.
const getDoctorDeletionRequests = asyncHandler(async (req, res) => {
  const result = await service.listDoctorDeletionRequests(req.user.sub);
  res.json({ ok: true, data: result });
});

// Handles the "respond to deletion request" endpoint and returns the service response.
const respondToDeletionRequest = asyncHandler(async (req, res) => {
  const { action } = respondDeletionRequestSchema.parse(req.body);
  const result = await service.respondToDeletionRequest(
    req.user.sub,
    req.params.requestId,
    action,
  );
  res.json({ ok: true, data: result });
});

// Handles the "get my notifications" endpoint and returns the service response.
const getMyNotifications = asyncHandler(async (req, res) => {
  const result = await service.listMyNotifications(req.user.sub);
  res.json({ ok: true, data: result });
});

module.exports = {
  createAccount,
  login,
  refresh,
  sendOtp,
  verifyEmailOtp,
  forgotPasswordSendOtp,
  resetPassword,
  changePassword,
  deleteAccount,
  logout,
  createPatientByDoctor,
  getMyQrCode,
  regenerateDoctorQrCode,
  scanDoctorQr,
  scanPatientQr,
  getDoctorConnectionRequests,
  respondToConnectionRequest,
  getDoctorActivePatients,
  getDoctorCreatedPatients,
  getDoctorDeletionRequests,
  respondToDeletionRequest,
  getMyNotifications,
};
