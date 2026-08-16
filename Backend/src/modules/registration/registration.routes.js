// Declares registration, QR, and doctor-patient linking routes.
const router = require("express").Router();
const controller = require("./registration.controller");
const { requireAuth, optionalAuth } = require("../../middlewares/auth.middleware");
const { requireRole } = require("../../middlewares/rbac.middleware");
const { doctorPhotoUploadFields } = require("../../common/utils/doctorPhoto");
const { requireCsrfForCookieAuth } = require("../../middlewares/csrf.middleware");
const { createRateLimiter, ipAndEmailKey } = require("../../middlewares/rate-limit.middleware");

const registrationLoginLimiter = createRateLimiter({
  name: "registration-login",
  windowMs: Number(process.env.RATE_LIMIT_LOGIN_WINDOW_MS || 10 * 60 * 1000),
  max: Number(process.env.RATE_LIMIT_LOGIN_MAX || 8),
  blockDurationMs: Number(process.env.RATE_LIMIT_LOGIN_BLOCK_MS || 15 * 60 * 1000),
  keyGenerator: ipAndEmailKey,
  message: "Too many login attempts. Please try again later.",
  code: "LOGIN_RATE_LIMITED",
});

const registrationRefreshLimiter = createRateLimiter({
  name: "registration-refresh",
  windowMs: Number(process.env.RATE_LIMIT_REFRESH_WINDOW_MS || 5 * 60 * 1000),
  max: Number(process.env.RATE_LIMIT_REFRESH_MAX || 20),
  blockDurationMs: Number(process.env.RATE_LIMIT_REFRESH_BLOCK_MS || 10 * 60 * 1000),
  message: "Too many token refresh attempts. Please try again later.",
  code: "REFRESH_RATE_LIMITED",
});

const otpSendLimiter = createRateLimiter({
  name: "otp-send",
  windowMs: Number(process.env.RATE_LIMIT_OTP_SEND_WINDOW_MS || 10 * 60 * 1000),
  max: Number(process.env.RATE_LIMIT_OTP_SEND_MAX || 5),
  blockDurationMs: Number(process.env.RATE_LIMIT_OTP_SEND_BLOCK_MS || 15 * 60 * 1000),
  keyGenerator: ipAndEmailKey,
  message: "Too many OTP requests. Please try again later.",
  code: "OTP_SEND_RATE_LIMITED",
});

const otpVerifyLimiter = createRateLimiter({
  name: "otp-verify",
  windowMs: Number(process.env.RATE_LIMIT_OTP_VERIFY_WINDOW_MS || 10 * 60 * 1000),
  max: Number(process.env.RATE_LIMIT_OTP_VERIFY_MAX || 10),
  blockDurationMs: Number(process.env.RATE_LIMIT_OTP_VERIFY_BLOCK_MS || 15 * 60 * 1000),
  keyGenerator: ipAndEmailKey,
  message: "Too many OTP verification attempts. Please try again later.",
  code: "OTP_VERIFY_RATE_LIMITED",
});

// 1) Create account (PATIENT/DOCTOR public, ADMIN only by admin token)
router.post(
  "/create-account",
  optionalAuth,
  doctorPhotoUploadFields,
  controller.createAccount,
);

// 2) Verify email OTP
router.post("/verify-email/send-otp", otpSendLimiter, controller.sendOtp);
router.post("/verify-email/confirm", otpVerifyLimiter, controller.verifyEmailOtp);

// 3) Login
router.post("/login", registrationLoginLimiter, controller.login);
router.post("/refresh", registrationRefreshLimiter, requireCsrfForCookieAuth, controller.refresh);

// 4) Forget password OTP
router.post("/forgot-password/send-otp", otpSendLimiter, controller.forgotPasswordSendOtp);
router.post("/forgot-password/reset", otpVerifyLimiter, controller.resetPassword);
router.post("/change-password", requireAuth, controller.changePassword);

// 5) Delete account
router.delete("/delete-account", requireAuth, controller.deleteAccount);

// 6) Logout
router.post("/logout", requireAuth, requireCsrfForCookieAuth, controller.logout);

// 7) My QR code (doctor/patient)
router.get("/my-qr", requireAuth, controller.getMyQrCode);

// Doctor permissions: create/list/link handling for patients
router.post(
  "/doctor/created-patient",
  requireAuth,
  requireRole("DOCTOR"),
  controller.createPatientByDoctor,
);
router.post(
  "/doctor/qr/regenerate",
  requireAuth,
  requireRole("DOCTOR"),
  controller.regenerateDoctorQrCode,
);
router.get(
  "/doctor/active-patients",
  requireAuth,
  requireRole("DOCTOR"),
  controller.getDoctorActivePatients,
);
router.get(
  "/doctor/created-patients",
  requireAuth,
  requireRole("DOCTOR"),
  controller.getDoctorCreatedPatients,
);

// Patient deletion flow to doctors
router.get(
  "/doctor/deletion-requests",
  requireAuth,
  requireRole("DOCTOR"),
  controller.getDoctorDeletionRequests,
);
router.post(
  "/doctor/deletion-requests/:requestId/respond",
  requireAuth,
  requireRole("DOCTOR"),
  controller.respondToDeletionRequest,
);

// Doctor connection requests
router.get(
  "/doctor/connect-requests",
  requireAuth,
  requireRole("DOCTOR"),
  controller.getDoctorConnectionRequests,
);
router.post(
  "/doctor/connect-requests/:requestId/respond",
  requireAuth,
  requireRole("DOCTOR"),
  controller.respondToConnectionRequest,
);

// QR scan workflows
router.post(
  "/scan/doctor-qr",
  requireAuth,
  requireRole("PATIENT"),
  controller.scanDoctorQr,
);
router.post(
  "/scan/patient-qr",
  requireAuth,
  requireRole("DOCTOR"),
  controller.scanPatientQr,
);

// Notifications
router.get("/notifications", requireAuth, controller.getMyNotifications);

module.exports = router;
