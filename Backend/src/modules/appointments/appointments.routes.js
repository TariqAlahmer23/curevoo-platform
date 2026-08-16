// Declares patient-side appointment routes.
const router = require("express").Router();
const controller = require("./appointments.controller");
const { requireAuth } = require("../../middlewares/auth.middleware");
const { requireRole } = require("../../middlewares/rbac.middleware");

router.use(requireAuth, requireRole("PATIENT"));

// Patient use cases: book/edit/delete/cancel/view appointments
router.post("/", controller.bookAppointment);
router.get("/", controller.viewAppointments);
router.put("/:id", controller.editAppointment);
router.post("/:id/cancel", controller.cancelAppointment);
router.delete("/:id", controller.deleteAppointment);

module.exports = router;
