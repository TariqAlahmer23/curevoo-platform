// Maps patient-facing account, profile, and appointment requests to the patients service.
const { asyncHandler } = require("../../common/utils/asyncHandler");
const { AppError } = require("../../common/errors/AppError");
const service = require("./patients.service");
const {
  registerPatientSchema,
  loginPatientSchema,
  patientForgotPasswordSchema,
  patientResetPasswordSchema,
  patientChangePasswordSchema,
  updateMeSchema,
  bookPatientAppointmentSchema,
  editPatientAppointmentSchema,
} = require("./patients.validation");
const {
  setRefreshTokenCookie,
  clearRefreshTokenCookie,
  getRefreshTokenFromRequest,
} = require("../auth/token.service");

// Handles the "patient register" endpoint and returns the service response.
const register = asyncHandler(async (req, res) => {
  const data = registerPatientSchema.parse({ ...req.body, role: "PATIENT" });
  const result = await service.registerPatient(data);

  setRefreshTokenCookie(res, result.refreshToken);
  res.status(201).json({
    ok: true,
    data: {
      user: result.user,
      accessToken: result.accessToken,
      qrString: result.qrString,
    },
  });
});

// Handles the "patient login" endpoint and returns the service response.
const login = asyncHandler(async (req, res) => {
  const data = loginPatientSchema.parse(req.body);
  const result = await service.login(data);

  setRefreshTokenCookie(res, result.refreshToken);
  res.json({
    ok: true,
    data: { user: result.user, accessToken: result.accessToken },
  });
});

// Handles the "patient refresh" endpoint and returns the service response.
const refresh = asyncHandler(async (req, res) => {
  const token = getRefreshTokenFromRequest(req);
  if (!token) {
    throw new AppError("Missing refresh token", 401, "NO_REFRESH_TOKEN");
  }

  const refreshed = await service.refresh(token, {
    ipAddress: req.ip,
    userAgent: req.get("user-agent") || null,
  });
  setRefreshTokenCookie(res, refreshed.refreshToken);
  res.json({ ok: true, data: { accessToken: refreshed.accessToken } });
});

// Handles the "patient validate token" endpoint and returns the service response.
const validateToken = asyncHandler(async (req, res) => {
  const result = await service.validateToken(req.user);
  res.json({ ok: true, data: result });
});

// Handles the "patient forgot password send otp" endpoint and returns the service response.
const forgotPasswordSendOtp = asyncHandler(async (req, res) => {
  const data = patientForgotPasswordSchema.parse(req.body);
  const result = await service.forgotPasswordSendOtp(data);
  res.json({ ok: true, data: result });
});

// Handles the "patient reset password" endpoint and returns the service response.
const resetPassword = asyncHandler(async (req, res) => {
  const data = patientResetPasswordSchema.parse(req.body);
  const result = await service.resetPassword(data);
  res.json({ ok: true, data: result });
});

// Handles the authenticated "patient change password" endpoint and returns the service response.
const changePassword = asyncHandler(async (req, res) => {
  const data = patientChangePasswordSchema.parse(req.body);
  const result = await service.changePassword(req.user.sub, data);
  res.json({ ok: true, data: result });
});

// Handles the "patient logout" endpoint and returns the service response.
const logout = asyncHandler(async (req, res) => {
  const token = getRefreshTokenFromRequest(req);
  const result = await service.logout(req.user.sub, token);
  clearRefreshTokenCookie(res);
  res.json({ ok: true, data: result });
});

// Handles the "get me" endpoint and returns the service response.
const getMe = asyncHandler(async (req, res) => {
  const me = await service.getMe(req.user.sub);
  res.json({ ok: true, data: me });
});

// Handles the "patient dashboard summary" endpoint and returns the service response.
const getDashboardSummary = asyncHandler(async (req, res) => {
  const result = await service.getDashboardSummary(req.user.sub);
  res.json({ ok: true, data: result });
});

// Handles the "update me" endpoint and returns the service response.
const updateMe = asyncHandler(async (req, res) => {
  const data = updateMeSchema.parse(req.body);
  const updated = await service.updateMe(req.user.sub, data);
  res.json({ ok: true, data: updated });
});

// Handles the "book appointment" endpoint and returns the service response.
const bookAppointment = asyncHandler(async (req, res) => {
  const data = bookPatientAppointmentSchema.parse(req.body);
  const result = await service.bookAppointment(req.user.sub, data);
  res.status(201).json({ ok: true, data: result });
});

// Handles the "view appointments" endpoint and returns the service response.
const viewAppointments = asyncHandler(async (req, res) => {
  const result = await service.viewAppointments(req.user.sub);
  res.json({ ok: true, data: result });
});

// Handles the "edit appointment" endpoint and returns the service response.
const editAppointment = asyncHandler(async (req, res) => {
  const data = editPatientAppointmentSchema.parse(req.body);
  const result = await service.editAppointment(req.user.sub, req.params.id, data);
  res.json({ ok: true, data: result });
});

// Handles the "cancel appointment" endpoint and returns the service response.
const cancelAppointment = asyncHandler(async (req, res) => {
  const result = await service.cancelAppointment(req.user.sub, req.params.id);
  res.json({ ok: true, data: result });
});

// Handles the "delete appointment" endpoint and returns the service response.
const deleteAppointment = asyncHandler(async (req, res) => {
  const result = await service.deleteAppointment(req.user.sub, req.params.id);
  res.json({ ok: true, data: result });
});

module.exports = {
  register,
  login,
  refresh,
  validateToken,
  forgotPasswordSendOtp,
  resetPassword,
  changePassword,
  logout,
  getMe,
  getDashboardSummary,
  updateMe,
  bookAppointment,
  viewAppointments,
  editAppointment,
  cancelAppointment,
  deleteAppointment,
};
