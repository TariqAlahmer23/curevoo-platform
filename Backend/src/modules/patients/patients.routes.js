// Declares patient-facing account, profile, and appointment routes.
const router = require("express").Router();
const controller = require("./patients.controller");
const { requireAuth } = require("../../middlewares/auth.middleware");
const { requireRole } = require("../../middlewares/rbac.middleware");
const { requireCsrfForCookieAuth } = require("../../middlewares/csrf.middleware");
const { createRateLimiter, ipAndEmailKey } = require("../../middlewares/rate-limit.middleware");

const patientLoginLimiter = createRateLimiter({
  name: "patients-login",
  windowMs: Number(process.env.RATE_LIMIT_LOGIN_WINDOW_MS || 10 * 60 * 1000),
  max: Number(process.env.RATE_LIMIT_LOGIN_MAX || 8),
  blockDurationMs: Number(process.env.RATE_LIMIT_LOGIN_BLOCK_MS || 15 * 60 * 1000),
  keyGenerator: ipAndEmailKey,
  message: "Too many login attempts. Please try again later.",
  code: "LOGIN_RATE_LIMITED",
});

const patientRefreshLimiter = createRateLimiter({
  name: "patients-refresh",
  windowMs: Number(process.env.RATE_LIMIT_REFRESH_WINDOW_MS || 5 * 60 * 1000),
  max: Number(process.env.RATE_LIMIT_REFRESH_MAX || 20),
  blockDurationMs: Number(process.env.RATE_LIMIT_REFRESH_BLOCK_MS || 10 * 60 * 1000),
  message: "Too many token refresh attempts. Please try again later.",
  code: "REFRESH_RATE_LIMITED",
});

const patientOtpSendLimiter = createRateLimiter({
  name: "patients-otp-send",
  windowMs: Number(process.env.RATE_LIMIT_OTP_SEND_WINDOW_MS || 10 * 60 * 1000),
  max: Number(process.env.RATE_LIMIT_OTP_SEND_MAX || 5),
  blockDurationMs: Number(process.env.RATE_LIMIT_OTP_SEND_BLOCK_MS || 15 * 60 * 1000),
  keyGenerator: ipAndEmailKey,
  message: "Too many OTP requests. Please try again later.",
  code: "OTP_SEND_RATE_LIMITED",
});

const patientOtpVerifyLimiter = createRateLimiter({
  name: "patients-otp-verify",
  windowMs: Number(process.env.RATE_LIMIT_OTP_VERIFY_WINDOW_MS || 10 * 60 * 1000),
  max: Number(process.env.RATE_LIMIT_OTP_VERIFY_MAX || 10),
  blockDurationMs: Number(process.env.RATE_LIMIT_OTP_VERIFY_BLOCK_MS || 15 * 60 * 1000),
  keyGenerator: ipAndEmailKey,
  message: "Too many OTP verification attempts. Please try again later.",
  code: "OTP_VERIFY_RATE_LIMITED",
});

// Patient account routes
router.post("/register", controller.register);
router.post("/login", patientLoginLimiter, controller.login);
router.post("/refresh", patientRefreshLimiter, requireCsrfForCookieAuth, controller.refresh);
router.get("/validate-token", requireAuth, requireRole("PATIENT"), controller.validateToken);
router.post("/forgot-password/send-otp", patientOtpSendLimiter, controller.forgotPasswordSendOtp);
router.post("/forgot-password/reset", patientOtpVerifyLimiter, controller.resetPassword);
router.post("/change-password", requireAuth, requireRole("PATIENT"), controller.changePassword);
router.post("/logout", requireAuth, requireRole("PATIENT"), requireCsrfForCookieAuth, controller.logout);

// Patient profile routes
router.get("/me", requireAuth, requireRole("PATIENT"), controller.getMe);
router.get("/dashboard/summary", requireAuth, requireRole("PATIENT"), controller.getDashboardSummary);
router.put("/me", requireAuth, requireRole("PATIENT"), controller.updateMe);

// Patient appointment routes
router.post("/appointments", requireAuth, requireRole("PATIENT"), controller.bookAppointment);
router.get("/appointments", requireAuth, requireRole("PATIENT"), controller.viewAppointments);
router.put("/appointments/:id", requireAuth, requireRole("PATIENT"), controller.editAppointment);
router.post(
  "/appointments/:id/cancel",
  requireAuth,
  requireRole("PATIENT"),
  controller.cancelAppointment,
);
router.delete(
  "/appointments/:id",
  requireAuth,
  requireRole("PATIENT"),
  controller.deleteAppointment,
);

module.exports = router;
