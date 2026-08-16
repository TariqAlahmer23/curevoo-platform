// Declares patient and doctor care-management routes.
const router = require("express").Router();
const controller = require("./care.controller");
const { requireAuth } = require("../../middlewares/auth.middleware");
const { requireRole } = require("../../middlewares/rbac.middleware");
const {
  medicalRecordImageUploadFields,
} = require("../../common/utils/medicalRecordImages");

router.use(requireAuth);

// Patient workflows
router.get(
  "/patient/treatment-plans/latest",
  requireRole("PATIENT"),
  controller.getMyLatestTreatmentPlan,
);
router.get(
  "/patient/treatment-plans/all",
  requireRole("PATIENT"),
  controller.listMyTreatmentPlans,
);
router.get(
  "/patient/treatment-plans",
  requireRole("PATIENT"),
  controller.listMyTreatmentPlans,
);
router.get(
  "/patient/history-record/latest",
  requireRole("PATIENT"),
  controller.getMyHistoryRecord,
);
router.get(
  "/patient/history-records/all",
  requireRole("PATIENT"),
  controller.listMyHistoryRecords,
);
router.get(
  "/patient/history-record",
  requireRole("PATIENT"),
  controller.getMyHistoryRecord,
);
router.post(
  "/patient/history-record",
  requireRole("PATIENT"),
  medicalRecordImageUploadFields,
  controller.createMyHistoryRecord,
);
router.post(
  "/patient/history-record/update-request",
  requireRole("PATIENT"),
  medicalRecordImageUploadFields,
  controller.requestMyHistoryRecordUpdate,
);

// Doctor workflows
router.get(
  "/doctor/patients/:patientUserId/treatment-plans/latest",
  requireRole("DOCTOR"),
  controller.getPatientLatestTreatmentPlan,
);
router.get(
  "/doctor/patients/:patientUserId/treatment-plans/all",
  requireRole("DOCTOR"),
  controller.listPatientTreatmentPlans,
);
router.get(
  "/doctor/patients/:patientUserId/treatment-plans",
  requireRole("DOCTOR"),
  controller.listPatientTreatmentPlans,
);
router.post(
  "/doctor/patients/:patientUserId/treatment-plans",
  requireRole("DOCTOR"),
  controller.createPatientTreatmentPlan,
);
router.post(
  "/doctor/treatment-plans",
  requireRole("DOCTOR"),
  controller.createTreatmentPlan,
);
router.put(
  "/doctor/patients/:patientUserId/treatment-plans/:planId",
  requireRole("DOCTOR"),
  controller.updateTreatmentPlan,
);
router.get(
  "/doctor/patients/:patientUserId/history-record/latest",
  requireRole("DOCTOR"),
  controller.getPatientHistoryRecord,
);
router.get(
  "/doctor/patients/:patientUserId/history-records/all",
  requireRole("DOCTOR"),
  controller.listPatientHistoryRecords,
);
router.get(
  "/doctor/patients/:patientUserId/history-record",
  requireRole("DOCTOR"),
  controller.getPatientHistoryRecord,
);
router.post(
  "/doctor/patients/:patientUserId/history-record",
  requireRole("DOCTOR"),
  medicalRecordImageUploadFields,
  controller.createPatientHistoryRecord,
);
router.put(
  "/doctor/patients/:patientUserId/history-record",
  requireRole("DOCTOR"),
  medicalRecordImageUploadFields,
  controller.updatePatientHistoryRecord,
);
router.put(
  "/doctor/patients/:patientId",
  requireRole("DOCTOR"),
  controller.updateCreatedPatient,
);
router.patch(
  "/doctor/patients/:patientId",
  requireRole("DOCTOR"),
  controller.updateCreatedPatient,
);
router.delete(
  "/doctor/patients/:patientId",
  requireRole("DOCTOR"),
  controller.deleteCreatedPatient,
);
router.get(
  "/doctor/history-update-requests",
  requireRole("DOCTOR"),
  controller.listDoctorHistoryUpdateRequests,
);
router.post(
  "/doctor/history-update-requests/:requestId/respond",
  requireRole("DOCTOR"),
  controller.respondHistoryUpdateRequest,
);

module.exports = router;
