// Declares patient-facing doctor directory routes.
const router = require("express").Router();
const controller = require("./doctor-patient.controller");
const { requireAuth } = require("../../middlewares/auth.middleware");
const { requireRole } = require("../../middlewares/rbac.middleware");

router.get(
  "/",
  requireAuth,
  requireRole("PATIENT"),
  controller.getActiveDoctors,
);

router.get(
  "/:id",
  requireAuth,
  requireRole("PATIENT"),
  controller.getDoctorDetail,
);

router.get(
  "/:id/available-times/day",
  requireAuth,
  requireRole("PATIENT"),
  controller.getDoctorAvailabilityForDate,
);

module.exports = router;
