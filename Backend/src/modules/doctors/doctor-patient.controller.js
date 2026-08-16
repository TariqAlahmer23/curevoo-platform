// Maps patient-facing doctor discovery requests to the doctor-patient service.
const { asyncHandler } = require("../../common/utils/asyncHandler");
const { availabilityDateQuerySchema } = require("./availability.validation");
const service = require("./doctor-patient.service");

// Get all active doctors with optional specialization filtering.
const getActiveDoctors = asyncHandler(async (req, res) => {
  const specialization = req.query.specialization || null;

  const result = await service.getActiveDoctors(specialization);
  res.json({ ok: true, ...result });
});

// Get specific doctor details with availability
const getDoctorDetail = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const result = await service.getDoctorDetail(id);
  res.json({ ok: true, data: result });
});

// Get one doctor's availability and already-booked times for a selected date.
const getDoctorAvailabilityForDate = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { date } = availabilityDateQuerySchema.parse(req.query);
  const result = await service.getDoctorAvailabilityForDate(id, date);
  res.json({ ok: true, data: result });
});

module.exports = {
  getActiveDoctors,
  getDoctorDetail,
  getDoctorAvailabilityForDate,
};
