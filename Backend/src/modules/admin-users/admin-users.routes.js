// Declares admin routes for doctor/patient management.
const router = require("express").Router();
const controller = require("./admin-users.controller");
const { requireAuth } = require("../../middlewares/auth.middleware");
const { requireRole } = require("../../middlewares/rbac.middleware");
const { doctorPhotoUploadFields } = require("../../common/utils/doctorPhoto");

router.use(requireAuth, requireRole("ADMIN"));

router.get("/doctors", controller.listDoctors);
router.post("/doctors", doctorPhotoUploadFields, controller.createDoctor);
router.put("/doctors/:userId", controller.updateDoctor);
router.delete("/doctors/:userId", controller.deleteDoctor);

router.get("/patients", controller.listPatients);
router.post("/patients", doctorPhotoUploadFields, controller.createPatient);
router.put("/patients/:userId", controller.updatePatient);
router.delete("/patients/:userId", controller.deletePatient);

module.exports = router;
