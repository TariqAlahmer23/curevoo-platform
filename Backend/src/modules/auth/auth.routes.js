// Declares public authentication routes.
const router = require("express").Router();
const controller = require("./auth.controller");
const { requireAuth } = require("../../middlewares/auth.middleware");
const { doctorPhotoUploadFields } = require("../../common/utils/doctorPhoto");
const { requireCsrfForCookieAuth } = require("../../middlewares/csrf.middleware");
const { createRateLimiter, ipAndEmailKey } = require("../../middlewares/rate-limit.middleware");

const authLoginLimiter = createRateLimiter({
  name: "auth-login",
  windowMs: Number(process.env.RATE_LIMIT_LOGIN_WINDOW_MS || 10 * 60 * 1000),
  max: Number(process.env.RATE_LIMIT_LOGIN_MAX || 8),
  blockDurationMs: Number(process.env.RATE_LIMIT_LOGIN_BLOCK_MS || 15 * 60 * 1000),
  keyGenerator: ipAndEmailKey,
  message: "Too many login attempts. Please try again later.",
  code: "LOGIN_RATE_LIMITED",
});

const authRefreshLimiter = createRateLimiter({
  name: "auth-refresh",
  windowMs: Number(process.env.RATE_LIMIT_REFRESH_WINDOW_MS || 5 * 60 * 1000),
  max: Number(process.env.RATE_LIMIT_REFRESH_MAX || 20),
  blockDurationMs: Number(process.env.RATE_LIMIT_REFRESH_BLOCK_MS || 10 * 60 * 1000),
  message: "Too many token refresh attempts. Please try again later.",
  code: "REFRESH_RATE_LIMITED",
});

router.post("/register", controller.register);
router.post(
  "/register-doctor",
  doctorPhotoUploadFields,
  controller.registerDoctor,
);
router.post("/login", authLoginLimiter, controller.login);
router.get("/validate-token", requireAuth, controller.validateToken);
router.post("/refresh", authRefreshLimiter, requireCsrfForCookieAuth, controller.refresh);
router.post("/logout", requireCsrfForCookieAuth, controller.logout);

module.exports = router;
