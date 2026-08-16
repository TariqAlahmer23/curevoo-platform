// Generates, verifies, and configures JWT-based session tokens.
const crypto = require("crypto");
const jwt = require("jsonwebtoken");
const { env } = require("../../config/env");

// Creates a short-lived access token for the authenticated user.
function signAccessToken({ userId, role }) {
  return jwt.sign({ sub: userId, role }, env.jwt.accessSecret, {
    expiresIn: env.jwt.accessTtl,
  });
}

// Creates a refresh token used to renew access sessions.
function signRefreshToken({ userId, role, jti }) {
  return jwt.sign({ sub: userId, role, jti }, env.jwt.refreshSecret, {
    expiresIn: env.jwt.refreshTtl,
  });
}

// Verifies and decodes the provided refresh token payload.
function verifyRefreshToken(token) {
  return jwt.verify(token, env.jwt.refreshSecret);
}

// Decodes token claims without verifying signature (for exp extraction after signing).
function decodeTokenClaims(token) {
  return jwt.decode(token);
}

// Generates a cryptographically secure token id used for refresh token rotation tracking.
function generateTokenId() {
  return crypto.randomUUID();
}

// Returns the cookie settings used when storing the refresh token.
function refreshCookieOptions() {
  const isProd = process.env.NODE_ENV === "production";
  const sameSite = (process.env.REFRESH_COOKIE_SAMESITE || "strict").toLowerCase();
  return {
    httpOnly: true,
    secure: isProd,
    sameSite: ["strict", "lax", "none"].includes(sameSite) ? sameSite : "strict",
    path: "/api",
  };
}

// Returns the legacy cookie settings used by older auth refresh flows.
function legacyRefreshCookieOptions() {
  const isProd = process.env.NODE_ENV === "production";
  const sameSite = (process.env.REFRESH_COOKIE_SAMESITE || "strict").toLowerCase();
  return {
    httpOnly: true,
    secure: isProd,
    sameSite: ["strict", "lax", "none"].includes(sameSite) ? sameSite : "strict",
    path: "/api/auth/refresh",
  };
}

// Returns cookie settings used for CSRF token double-submit protection.
function csrfCookieOptions() {
  const isProd = process.env.NODE_ENV === "production";
  const sameSite = (process.env.REFRESH_COOKIE_SAMESITE || "strict").toLowerCase();
  return {
    httpOnly: false,
    secure: isProd,
    sameSite: ["strict", "lax", "none"].includes(sameSite) ? sameSite : "strict",
    path: "/api",
  };
}

// Stores the refresh token cookie using the shared auth settings.
function setRefreshTokenCookie(res, token) {
  res.clearCookie("refresh_token", legacyRefreshCookieOptions());
  res.cookie("refresh_token", token, refreshCookieOptions());
  res.cookie("csrf_token", crypto.randomBytes(32).toString("hex"), csrfCookieOptions());
}

// Clears the refresh token cookie using the same cookie path.
function clearRefreshTokenCookie(res) {
  res.clearCookie("refresh_token", refreshCookieOptions());
  res.clearCookie("refresh_token", legacyRefreshCookieOptions());
  res.clearCookie("csrf_token", csrfCookieOptions());
}

// Reads the refresh token from either the cookie or the request body.
function getRefreshTokenFromRequest(req) {
  return req.cookies?.refresh_token || req.body?.refreshToken || null;
}

module.exports = {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
  decodeTokenClaims,
  generateTokenId,
  refreshCookieOptions,
  legacyRefreshCookieOptions,
  csrfCookieOptions,
  setRefreshTokenCookie,
  clearRefreshTokenCookie,
  getRefreshTokenFromRequest,
};
