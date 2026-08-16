// Extracts and verifies bearer tokens for protected and optional-auth routes.
const jwt = require("jsonwebtoken");
const { env } = require("../config/env");
const { AppError } = require("../common/errors/AppError");

// Rejects requests that do not provide a valid bearer access token.
function requireAuth(req, res, next) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) return next(new AppError("Unauthorized", 401, "UNAUTHORIZED"));

  try {
    const payload = jwt.verify(token, env.jwt.accessSecret);
    req.user = payload; // { sub, role }
    return next();
  } catch {
    return next(new AppError("Unauthorized", 401, "UNAUTHORIZED"));
  }
}

// Attaches the authenticated user when a valid bearer token is present.
function optionalAuth(req, res, next) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) return next();

  try {
    const payload = jwt.verify(token, env.jwt.accessSecret);
    req.user = payload;
  } catch {
    // Ignore invalid token for optional auth path.
  }
  return next();
}

module.exports = { requireAuth, optionalAuth };
