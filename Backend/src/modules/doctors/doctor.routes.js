// Declares doctor self-service, photo, and availability routes.
const router = require("express").Router();
const controller = require("./doctor.controller");
const availabilityController = require("./availability.controller");
const { requireAuth } = require("../../middlewares/auth.middleware");
const { requireRole } = require("../../middlewares/rbac.middleware");
const { doctorPhotoUploadFields } = require("../../common/utils/doctorPhoto");

router.use(requireAuth, requireRole("DOCTOR"));

// Profile Routes
router.get("/profile", controller.getProfile);
router.put("/profile", controller.updateProfile);

// Photo Routes
router.post("/photo", doctorPhotoUploadFields, controller.uploadPhoto);
router.put("/photo", doctorPhotoUploadFields, controller.updatePhoto);
router.post("/profile/qr/regenerate", controller.regenerateQrCode);

// Settings Routes
router.get("/settings", controller.getSettings);
router.put("/settings", controller.updateSettings);

// Doctor Patients Routes
router.get("/dashboard/summary", controller.getDashboardSummary);
router.get("/patients", controller.getPatients);
router.post("/patients", controller.createPatient);
router.get("/patients/:patientId", controller.getPatientById);
router.put("/patients/:patientId", controller.updatePatient);
router.patch("/patients/:patientId", controller.updatePatient);
router.delete("/patients/:patientId", controller.deletePatient);
router.get(
  "/patients/:patientId/medical-history/latest",
  controller.getPatientLatestMedicalHistory,
);
router.get(
  "/patients/:patientId/medical-history/all",
  controller.getPatientAllMedicalHistories,
);
router.get("/patients/:patientId/medical-history", controller.getPatientMedicalHistory);
router.get(
  "/patients/:patientId/medical-records/latest",
  controller.getPatientLatestMedicalRecord,
);
router.get(
  "/patients/:patientId/medical-records/all",
  controller.getPatientAllMedicalRecords,
);
router.get("/patients/:patientId/medical-records", controller.getPatientMedicalRecords);
router.get(
  "/patients/:patientId/treatment-plans/latest",
  controller.getPatientLatestTreatmentPlan,
);
router.get(
  "/patients/:patientId/treatment-plans/all",
  controller.getPatientAllTreatmentPlans,
);
router.get("/patients/:patientId/treatment-plans", controller.getPatientTreatmentPlans);

// Available Times Routes
router.post("/available-times", availabilityController.createAvailableTime);
router.get("/available-times", availabilityController.getAvailableTimes);
router.get(
  "/available-times/day",
  availabilityController.getAvailableTimesForDate,
);
router.put("/available-times", availabilityController.updateAvailableTime);
router.delete(
  "/available-times/:id",
  availabilityController.deleteAvailableTime,
);

// Doctor Status Routes
router.get("/status", availabilityController.getStatus);
router.put("/status", availabilityController.updateStatus);

module.exports = router;
