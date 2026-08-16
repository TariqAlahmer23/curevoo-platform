// Maps patient and doctor appointment requests to the appointment service layer.
const { asyncHandler } = require("../../common/utils/asyncHandler");
const service = require("./appointments.service");
const {
  bookAppointmentSchema,
  bookDoctorAppointmentSchema,
  bookedSlotsQuerySchema,
  editAppointmentSchema,
  respondAppointmentSchema,
} = require("./appointments.validation");

// Handles the "book appointment" endpoint and returns the service response.
const bookAppointment = asyncHandler(async (req, res) => {
  const data = bookAppointmentSchema.parse(req.body);
  const result = await service.bookAppointment(req.user.sub, data);
  res.status(201).json({ ok: true, data: result });
});

// Handles the doctor-created appointment endpoint and returns the service response.
const bookDoctorAppointment = asyncHandler(async (req, res) => {
  const data = bookDoctorAppointmentSchema.parse(req.body);
  const result = await service.bookDoctorAppointment(req.user.sub, data);
  res.status(201).json({ ok: true, data: result });
});

// Handles the "view appointments" endpoint and returns the service response.
const viewAppointments = asyncHandler(async (req, res) => {
  const result = await service.viewAppointments(req.user.sub);
  res.json({ ok: true, data: result });
});

// Handles the "edit appointment" endpoint and returns the service response.
const editAppointment = asyncHandler(async (req, res) => {
  const data = editAppointmentSchema.parse(req.body);
  const result = await service.editAppointment(
    req.user.sub,
    req.params.id,
    data,
  );
  res.json({ ok: true, data: result });
});

// Handles the doctor-side "edit appointment" endpoint and returns the service response.
const editDoctorAppointment = asyncHandler(async (req, res) => {
  const data = editAppointmentSchema.parse(req.body);
  const result = await service.editDoctorAppointment(
    req.user.sub,
    req.params.id,
    data,
  );
  res.json({ ok: true, data: result });
});

// Handles the "cancel appointment" endpoint and returns the service response.
const cancelAppointment = asyncHandler(async (req, res) => {
  const result = await service.cancelAppointment(req.user.sub, req.params.id);
  res.json({ ok: true, data: result });
});

// Handles the "delete appointment" endpoint and returns the service response.
const deleteAppointment = asyncHandler(async (req, res) => {
  const result = await service.deleteAppointment(req.user.sub, req.params.id);
  res.json({ ok: true, data: result });
});

// Handles the doctor-side "delete appointment" endpoint and returns the service response.
const deleteDoctorAppointment = asyncHandler(async (req, res) => {
  const result = await service.deleteDoctorAppointment(req.user.sub, req.params.id);
  res.json({ ok: true, data: result });
});

// Handles the "list doctor appointments" endpoint and returns the service response.
const listDoctorAppointments = asyncHandler(async (req, res) => {
  const status =
    typeof req.query.status === "string" ? req.query.status : null;
  const result = await service.listDoctorAppointments(req.user.sub, status);
  res.json({ ok: true, data: result });
});

// Handles the "list accepted doctor appointments" endpoint.
const listAcceptedDoctorAppointments = asyncHandler(async (req, res) => {
  const result = await service.listDoctorAppointments(req.user.sub, "CONFIRMED");
  res.json({ ok: true, data: result });
});

// Handles the "list doctor-created appointments" endpoint.
const listCreatedDoctorAppointments = asyncHandler(async (req, res) => {
  const result = await service.listDoctorAppointments(req.user.sub, "CREATED");
  res.json({ ok: true, data: result });
});

// Handles the "list canceled doctor appointments" endpoint.
const listCanceledDoctorAppointments = asyncHandler(async (req, res) => {
  const result = await service.listDoctorAppointments(req.user.sub, "CANCELED");
  res.json({ ok: true, data: result });
});

// Handles the "list pending doctor appointments" endpoint.
const listPendingDoctorAppointments = asyncHandler(async (req, res) => {
  const result = await service.listDoctorAppointments(req.user.sub, "PENDING");
  res.json({ ok: true, data: result });
});

// Handles the "list upcoming doctor appointments" endpoint.
const listUpcomingDoctorAppointments = asyncHandler(async (req, res) => {
  const result = await service.listUpcomingDoctorAppointments(req.user.sub);
  res.json({ ok: true, data: result });
});

// Handles the "list doctor booked slots" endpoint and returns the service response.
const getDoctorBookedSlots = asyncHandler(async (req, res) => {
  const query = bookedSlotsQuerySchema.parse(req.query);
  const result = await service.getDoctorBookedSlots(req.user.sub, query);
  res.json({ ok: true, data: result });
});

// Handles the "get one doctor booked slot by id" endpoint and returns the service response.
const getDoctorBookedSlotById = asyncHandler(async (req, res) => {
  const result = await service.getDoctorBookedSlotById(req.user.sub, req.params.id);
  res.json({ ok: true, data: result });
});

// Handles the "respond to appointment" endpoint and returns the service response.
const respondToAppointment = asyncHandler(async (req, res) => {
  const { action } = respondAppointmentSchema.parse(req.body);
  const result = await service.respondToAppointment(
    req.user.sub,
    req.params.id,
    action,
  );
  res.json({ ok: true, data: result });
});

module.exports = {
  bookAppointment,
  bookDoctorAppointment,
  viewAppointments,
  editAppointment,
  editDoctorAppointment,
  cancelAppointment,
  deleteAppointment,
  deleteDoctorAppointment,
  getDoctorBookedSlots,
  getDoctorBookedSlotById,
  listDoctorAppointments,
  listAcceptedDoctorAppointments,
  listCreatedDoctorAppointments,
  listCanceledDoctorAppointments,
  listPendingDoctorAppointments,
  listUpcomingDoctorAppointments,
  respondToAppointment,
};
