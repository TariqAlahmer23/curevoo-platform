// Maps auth HTTP requests to the auth service layer.
const { asyncHandler } = require("../../common/utils/asyncHandler");
const { AppError } = require("../../common/errors/AppError");
const {
  createAccountSchema,
  loginSchema,
} = require("../registration/registration.validation");
const authService = require("./auth.service");
const {
  setRefreshTokenCookie,
  clearRefreshTokenCookie,
  getRefreshTokenFromRequest,
} = require("./token.service");
const {
  buildDoctorPhotoUrl,
  getUploadedDoctorPhoto,
  removeUploadedFile,
  validateDoctorPhotoFile,
} = require("../../common/utils/doctorPhoto");

// Handles the "register" endpoint and returns the service response.
const register = asyncHandler(async (req, res) => {
  const data = createAccountSchema.parse({ ...req.body, role: "PATIENT" });
  const result = await authService.registerPatient(data);

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

// Handles the "register doctor" endpoint and returns the service response.
const registerDoctor = asyncHandler(async (req, res) => {
  const photoFile = getUploadedDoctorPhoto(req);

  try {
    const data = createAccountSchema.parse({ ...req.body, role: "DOCTOR" });
    if (photoFile) validateDoctorPhotoFile(photoFile);

    const result = await authService.registerDoctor({
      ...data,
      photoUrl: photoFile ? buildDoctorPhotoUrl(photoFile) : undefined,
    });

    setRefreshTokenCookie(res, result.refreshToken);
    res.status(201).json({
      ok: true,
      data: {
        user: result.user,
        accessToken: result.accessToken,
        qrString: result.qrString,
      },
    });
  } catch (error) {
    if (photoFile) removeUploadedFile(photoFile);
    throw error;
  }
});

// Handles the "login" endpoint and returns the service response.
const login = asyncHandler(async (req, res) => {
  const data = loginSchema.parse(req.body);
  const result = await authService.login(data);

  setRefreshTokenCookie(res, result.refreshToken);
  res.json({
    ok: true,
    data: { user: result.user, accessToken: result.accessToken },
  });
});

// Handles the "validate token" endpoint and returns the authenticated user payload.
const validateToken = asyncHandler(async (req, res) => {
  res.json({
    ok: true,
    data: {
      valid: true,
      user: {
        id: req.user.sub,
        role: req.user.role,
      },
    },
  });
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

// Handles the "logout" endpoint and returns the service response.
const logout = asyncHandler(async (req, res) => {
  const token = getRefreshTokenFromRequest(req);
  await authService.revokeRefreshTokenByToken(token, "LOGOUT");
  clearRefreshTokenCookie(res);
  res.json({ ok: true });
});

module.exports = {
  register,
  registerDoctor,
  login,
  validateToken,
  refresh,
  logout,
};
