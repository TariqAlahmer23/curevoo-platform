// Declares doctor-side appointment review and response routes.
const router = require("express").Router();
const controller = require("./appointments.controller");
const { requireAuth } = require("../../middlewares/auth.middleware");
const { requireRole } = require("../../middlewares/rbac.middleware");

router.use(requireAuth, requireRole("DOCTOR"));

// Doctor use cases: view appointments across statuses and approve/reject pending ones
router.post("/", controller.bookDoctorAppointment);
router.get("/", controller.listDoctorAppointments);
router.get("/accepted", controller.listAcceptedDoctorAppointments);
router.get("/created", controller.listCreatedDoctorAppointments);
router.get("/canceled", controller.listCanceledDoctorAppointments);
router.get("/pending", controller.listPendingDoctorAppointments);
router.get("/upcoming", controller.listUpcomingDoctorAppointments);
router.get("/booked-slots", controller.getDoctorBookedSlots);
router.get("/booked-slots/:id", controller.getDoctorBookedSlotById);
router.put("/:id", controller.editDoctorAppointment);
router.delete("/:id", controller.deleteDoctorAppointment);
router.post("/:id/respond", controller.respondToAppointment);

module.exports = router;
