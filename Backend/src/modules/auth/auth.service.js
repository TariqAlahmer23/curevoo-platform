// Implements registration, login, and token refresh workflows.
const { randomUUID } = require("crypto");
const { AppError } = require("../../common/errors/AppError");
const {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
  decodeTokenClaims,
} = require("./token.service");
const registrationService = require("../registration/registration.service");
const registrationRepo = require("../registration/registration.repo");

// Executes the "register patient" business workflow for this module.
async function registerPatient({ email, password, fullName }) {
  return registrationService.createAccount(
    { email, password, fullName, role: "PATIENT" },
    null,
  );
}

// Executes the "register doctor" business workflow for this module.
async function registerDoctor({
  email,
  password,
  fullName,
  phoneNumber,
  age,
  specialization,
  workingAt,
  experience,
  location,
  languages,
  photoUrl,
}) {
  return registrationService.createAccount(
    {
      email,
      password,
      fullName,
      phoneNumber,
      age,
      specialization,
      workingAt,
      experience,
      location,
      languages,
      photoUrl,
      role: "DOCTOR",
    },
    null,
  );
}

// Executes the "login" business workflow for this module.
async function login({ email, password }) {
  const result = await registrationService.login({ email, password });

  return {
    accessToken: result.accessToken,
    refreshToken: result.refreshToken,
    user: {
      id: result.user.id,
      email: result.user.email,
      role: result.user.role,
    },
  };
}

function getTokenExpiresAt(token) {
  const claims = decodeTokenClaims(token);
  if (!claims?.exp) {
    throw new AppError("Unable to determine token expiry", 500, "TOKEN_EXP_PARSE_FAILED");
  }
  return new Date(claims.exp * 1000);
}

// Executes the "refresh" business workflow for this module.
async function refresh(refreshToken, meta = {}) {
  let payload;
  try {
    payload = verifyRefreshToken(refreshToken);
  } catch {
    throw new AppError("Invalid refresh token", 401, "INVALID_REFRESH");
  }

  if (!payload?.jti) {
    throw new AppError("Invalid refresh token", 401, "INVALID_REFRESH");
  }

  const currentSession = await registrationRepo.findRefreshTokenSessionByJti(payload.jti);
  if (!currentSession || currentSession.userId !== payload.sub) {
    throw new AppError("Invalid refresh token", 401, "INVALID_REFRESH");
  }

  if (currentSession.revokedAt || currentSession.expiresAt <= new Date()) {
    if (currentSession.revokeReason === "ROTATED") {
      await registrationRepo.revokeAllRefreshTokenSessionsForUser(
        currentSession.userId,
        "TOKEN_REUSE_DETECTED",
      );
      throw new AppError("Session compromised. Please login again.", 401, "SESSION_COMPROMISED");
    }
    throw new AppError("Invalid refresh token", 401, "INVALID_REFRESH");
  }

  const user = await registrationRepo.findUserById(payload.sub);
  if (!user) throw new AppError("User not found", 401, "INVALID_REFRESH");

  const accessToken = signAccessToken({ userId: user.id, role: user.role });
  const nextJti = randomUUID();
  const newRefreshToken = signRefreshToken({
    userId: user.id,
    role: user.role,
    jti: nextJti,
  });

  await registrationRepo.revokeRefreshTokenSessionByJti(payload.jti, {
    replacedByJti: nextJti,
    revokeReason: "ROTATED",
  });
  await registrationRepo.createRefreshTokenSession({
    userId: user.id,
    jti: nextJti,
    expiresAt: getTokenExpiresAt(newRefreshToken),
    userAgent: meta.userAgent,
    ipAddress: meta.ipAddress,
  });

  return { accessToken, refreshToken: newRefreshToken };
}

// Executes the "revoke refresh token by token string" workflow.
async function revokeRefreshTokenByToken(refreshToken, reason = "LOGOUT") {
  if (!refreshToken) return { revoked: false };

  let payload = null;
  try {
    payload = verifyRefreshToken(refreshToken);
  } catch {
    return { revoked: false };
  }

  if (!payload?.jti) return { revoked: false };
  await registrationRepo.revokeRefreshTokenSessionByJti(payload.jti, {
    revokeReason: reason,
  });
  return { revoked: true };
}

// Executes the "logout all user sessions" workflow.
async function logoutAllSessions(userId) {
  await registrationRepo.revokeAllRefreshTokenSessionsForUser(userId, "GLOBAL_LOGOUT");
  return { ok: true };
}

module.exports = {
  registerPatient,
  registerDoctor,
  login,
  refresh,
  revokeRefreshTokenByToken,
  logoutAllSessions,
};
