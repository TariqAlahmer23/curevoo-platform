// Maps doctor availability and status endpoints to the availability service.
const { asyncHandler } = require("../../common/utils/asyncHandler");
const {
  createAvailableTimeSchema,
  availabilityDateQuerySchema,
  updateAvailableTimeSchema,
  updateDoctorStatusSchema,
} = require("./availability.validation");
const service = require("./availability.service");

// Available Times Endpoints
const createAvailableTime = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const data = createAvailableTimeSchema.parse(req.body);
  const result = await service.createAvailableTimeSlot(userId, data);
  res.status(201).json({ ok: true, data: result });
});

// Handles the "get available times" endpoint and returns the service response.
const getAvailableTimes = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const result = await service.getAvailableTimes(userId);
  res.json({ ok: true, data: result });
});

// Handles the "get available times by date" endpoint and returns the service response.
const getAvailableTimesForDate = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const { date } = availabilityDateQuerySchema.parse(req.query);
  const result = await service.getAvailableTimesForDate(userId, date);
  res.json({ ok: true, data: result });
});

// Handles the "update available time" endpoint and returns the service response.
const updateAvailableTime = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const data = updateAvailableTimeSchema.parse(req.body);
  const result = await service.updateAvailableTimeSlot(userId, data);
  res.json({ ok: true, data: result });
});

// Handles the "delete available time" endpoint and returns the service response.
const deleteAvailableTime = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const { id } = req.params;
  await service.deleteAvailableTimeSlot(userId, id);
  res.json({ ok: true, message: "Available time deleted successfully" });
});

// Doctor Status Endpoints
const updateStatus = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const data = updateDoctorStatusSchema.parse(req.body);
  const result = await service.updateStatus(userId, data.isActive);
  res.json({ ok: true, data: result });
});

// Handles the "get status" endpoint and returns the service response.
const getStatus = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const result = await service.getStatus(userId);
  res.json({ ok: true, data: result });
});

module.exports = {
  createAvailableTime,
  getAvailableTimes,
  getAvailableTimesForDate,
  updateAvailableTime,
  deleteAvailableTime,
  updateStatus,
  getStatus,
};
