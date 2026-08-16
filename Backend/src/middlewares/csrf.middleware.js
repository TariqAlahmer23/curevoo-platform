// Enforces CSRF double-submit checks for cookie-authenticated state-changing endpoints.
const { AppError } = require("../common/errors/AppError");

function requireCsrfForCookieAuth(req, res, next) {
  const hasRefreshCookie = !!req.cookies?.refresh_token;
  if (!hasRefreshCookie) return next();

  const csrfCookie = req.cookies?.csrf_token;
  const csrfHeader = req.get("x-csrf-token");

  if (!csrfCookie || !csrfHeader || csrfCookie !== csrfHeader) {
    return next(new AppError("CSRF token is missing or invalid", 403, "CSRF_INVALID"));
  }

  return next();
}

module.exports = {
  requireCsrfForCookieAuth,
};
