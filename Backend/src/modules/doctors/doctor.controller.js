// Maps doctor self-service endpoints to the doctor service layer.
const { asyncHandler } = require("../../common/utils/asyncHandler");
const {
  updateDoctorProfileSchema,
  updateDoctorSettingsSchema,
  createDoctorPatientSchema,
  updateDoctorCreatedPatientSchema,
} = require("./doctor.validation");
const service = require("./doctor.service");
const { AppError } = require("../../common/errors/AppError");
const {
  buildDoctorPhotoUrl,
  getUploadedDoctorPhoto,
  removeUploadedFile,
  validateDoctorPhotoFile,
} = require("../../common/utils/doctorPhoto");

// Profile Endpoints
const getProfile = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const profile = await service.getProfile(userId);
  res.json({ ok: true, data: profile });
});

// Handles the "update profile" endpoint and returns the service response.
const updateProfile = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const data = updateDoctorProfileSchema.parse(req.body);
  const updated = await service.updateProfile(userId, data);
  res.json({ ok: true, data: updated });
});

// Photo Endpoints
const uploadPhoto = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const photoFile = getUploadedDoctorPhoto(req);

  if (!photoFile) {
    throw new AppError("No file provided", 400, "NO_FILE");
  }

  try {
    validateDoctorPhotoFile(photoFile);
    const photoUrl = buildDoctorPhotoUrl(photoFile);
    const updated = await service.uploadPhoto(userId, photoUrl);

    res.json({
      ok: true,
      data: { photoUrl: updated.photoUrl },
    });
  } catch (error) {
    removeUploadedFile(photoFile);
    throw error;
  }
});

// Handles the "update photo" endpoint and returns the service response.
const updatePhoto = asyncHandler(async (req, res) => {
  // Same as uploadPhoto - PUT and POST both upload/replace photo
  return uploadPhoto(req, res);
});

// Handles the "regenerate qr code" endpoint and returns the service response.
const regenerateQrCode = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const updated = await service.regenerateQrCode(userId);
  res.json({ ok: true, data: updated });
});

// Settings Endpoints
const getSettings = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const settings = await service.getSettings(userId);
  res.json({ ok: true, data: settings });
});

// Handles the "update settings" endpoint and returns the service response.
const updateSettings = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const data = updateDoctorSettingsSchema.parse(req.body);
  const updated = await service.updateSettings(userId, data);
  res.json({ ok: true, data: updated });
});

// Handles the "list doctor patients" endpoint and returns the service response.
const getPatients = asyncHandler(async (req, res) => {
  const result = await service.listPatients(req.user.sub);
  res.json({ ok: true, data: result });
});

// Handles the "doctor dashboard summary" endpoint and returns the service response.
const getDashboardSummary = asyncHandler(async (req, res) => {
  const result = await service.getDashboardSummary(req.user.sub);
  res.json({ ok: true, data: result });
});

// Handles the "create patient as doctor" endpoint and returns the service response.
const createPatient = asyncHandler(async (req, res) => {
  const data = createDoctorPatientSchema.parse(req.body);
  const result = await service.createPatient(req.user.sub, data);
  res.status(201).json({ ok: true, data: result });
});

// Handles the "get doctor patient by id" endpoint and returns the service response.
const getPatientById = asyncHandler(async (req, res) => {
  const result = await service.getPatientById(req.user.sub, req.params.patientId);
  res.json({ ok: true, data: result });
});

// Handles the "update doctor-created patient" endpoint and returns the service response.
const updatePatient = asyncHandler(async (req, res) => {
  const data = updateDoctorCreatedPatientSchema.parse(req.body);
  const result = await service.updatePatient(
    req.user.sub,
    req.params.patientId,
    data,
  );
  res.json({ ok: true, data: result });
});

// Handles the "delete doctor-created patient" endpoint and returns the service response.
const deletePatient = asyncHandler(async (req, res) => {
  const result = await service.deletePatient(req.user.sub, req.params.patientId);
  res.json({ ok: true, data: result });
});

// Handles the "get doctor patient medical history" endpoint and returns the service response.
const getPatientMedicalHistory = asyncHandler(async (req, res) => {
  const result = await service.getPatientMedicalHistory(
    req.user.sub,
    req.params.patientId,
  );
  res.json({ ok: true, data: result });
});

// Handles the "get doctor patient latest medical history" endpoint and returns the service response.
const getPatientLatestMedicalHistory = asyncHandler(async (req, res) => {
  const result = await service.getPatientLatestMedicalHistory(
    req.user.sub,
    req.params.patientId,
  );
  res.json({ ok: true, data: result });
});

// Handles the "list doctor patient medical histories" endpoint and returns the service response.
const getPatientAllMedicalHistories = asyncHandler(async (req, res) => {
  const result = await service.getPatientAllMedicalHistories(
    req.user.sub,
    req.params.patientId,
  );
  res.json({ ok: true, data: result });
});

// Handles the "get doctor patient medical records" endpoint and returns the service response.
const getPatientMedicalRecords = asyncHandler(async (req, res) => {
  const result = await service.getPatientMedicalRecords(
    req.user.sub,
    req.params.patientId,
  );
  res.json({ ok: true, data: result });
});

// Handles the "get doctor patient latest medical record" endpoint and returns the service response.
const getPatientLatestMedicalRecord = asyncHandler(async (req, res) => {
  const result = await service.getPatientLatestMedicalRecord(
    req.user.sub,
    req.params.patientId,
  );
  res.json({ ok: true, data: result });
});

// Handles the "list doctor patient medical records" endpoint and returns the service response.
const getPatientAllMedicalRecords = asyncHandler(async (req, res) => {
  const result = await service.getPatientAllMedicalRecords(
    req.user.sub,
    req.params.patientId,
  );
  res.json({ ok: true, data: result });
});

// Handles the "get doctor patient treatment plans" endpoint and returns the service response.
const getPatientTreatmentPlans = asyncHandler(async (req, res) => {
  const result = await service.getPatientTreatmentPlans(
    req.user.sub,
    req.params.patientId,
  );
  res.json({ ok: true, data: result });
});

// Handles the "get doctor patient latest treatment plan" endpoint and returns the service response.
const getPatientLatestTreatmentPlan = asyncHandler(async (req, res) => {
  const result = await service.getPatientLatestTreatmentPlan(
    req.user.sub,
    req.params.patientId,
  );
  res.json({ ok: true, data: result });
});

// Handles the "list doctor patient treatment plans" endpoint and returns the service response.
const getPatientAllTreatmentPlans = asyncHandler(async (req, res) => {
  const result = await service.getPatientAllTreatmentPlans(
    req.user.sub,
    req.params.patientId,
  );
  res.json({ ok: true, data: result });
});

module.exports = {
  // Profile
  getProfile,
  updateProfile,
  // Photo
  uploadPhoto,
  updatePhoto,
  regenerateQrCode,
  // Settings
  getSettings,
  updateSettings,
  // Patients
  getPatients,
  getDashboardSummary,
  createPatient,
  getPatientById,
  updatePatient,
  deletePatient,
  getPatientMedicalHistory,
  getPatientLatestMedicalHistory,
  getPatientAllMedicalHistories,
  getPatientMedicalRecords,
  getPatientLatestMedicalRecord,
  getPatientAllMedicalRecords,
  getPatientTreatmentPlans,
  getPatientLatestTreatmentPlan,
  getPatientAllTreatmentPlans,
};
