// Maps treatment plan and medical history requests to the care service layer.
const { asyncHandler } = require("../../common/utils/asyncHandler");
const service = require("./care.service");
const {
  createTreatmentPlanSchema,
  createTreatmentPlanForDoctorPatientSchema,
  updateTreatmentPlanSchema,
  createHistoryRecordSchema,
  requestHistoryRecordUpdateSchema,
  updateHistoryRecordByDoctorSchema,
  respondHistoryUpdateRequestSchema,
} = require("./care.validation");
const {
  updateDoctorCreatedPatientSchema,
} = require("../doctors/doctor.validation");
const {
  getUploadedMedicalRecordImages,
  removeUploadedMedicalRecordImages,
  validateMedicalRecordImageFiles,
  buildMedicalRecordImageEntries,
} = require("../../common/utils/medicalRecordImages");

function mergeUploadedRecordImages(record, uploadedImages) {
  if (!uploadedImages.length) return record;

  const existingImages = Array.isArray(record?.images) ? record.images : [];
  return {
    ...record,
    images: [...existingImages, ...buildMedicalRecordImageEntries(uploadedImages)],
  };
}

async function withHistoryRecordPayload(req, schema, action) {
  const uploadedImages = getUploadedMedicalRecordImages(req);

  try {
    validateMedicalRecordImageFiles(uploadedImages);
    const data = schema.parse(req.body);

    return await action({
      ...data,
      record: mergeUploadedRecordImages(data.record, uploadedImages),
    });
  } catch (error) {
    removeUploadedMedicalRecordImages(uploadedImages);
    throw error;
  }
}

// Handles the "list my treatment plans" endpoint and returns the service response.
const listMyTreatmentPlans = asyncHandler(async (req, res) => {
  const result = await service.listMyTreatmentPlans(req.user.sub);
  res.json({ ok: true, data: result });
});

// Handles the "get my latest treatment plan" endpoint and returns the service response.
const getMyLatestTreatmentPlan = asyncHandler(async (req, res) => {
  const result = await service.getMyLatestTreatmentPlan(req.user.sub);
  res.json({ ok: true, data: result });
});

// Handles the "list patient treatment plans" endpoint and returns the service response.
const listPatientTreatmentPlans = asyncHandler(async (req, res) => {
  const result = await service.listPatientTreatmentPlans(
    req.user.sub,
    req.params.patientUserId,
  );
  res.json({ ok: true, data: result });
});

// Handles the "get patient latest treatment plan" endpoint and returns the service response.
const getPatientLatestTreatmentPlan = asyncHandler(async (req, res) => {
  const result = await service.getPatientLatestTreatmentPlan(
    req.user.sub,
    req.params.patientUserId,
  );
  res.json({ ok: true, data: result });
});

// Handles the "create treatment plan" endpoint and returns the service response.
const createTreatmentPlan = asyncHandler(async (req, res) => {
  const data = createTreatmentPlanSchema.parse(req.body);
  const result = await service.createTreatmentPlan(req.user.sub, data);
  res.status(201).json({ ok: true, data: result });
});

// Handles the "create treatment plan by patient route id" endpoint and returns the service response.
const createPatientTreatmentPlan = asyncHandler(async (req, res) => {
  const data = createTreatmentPlanForDoctorPatientSchema.parse(req.body);
  const result = await service.createPatientTreatmentPlan(
    req.user.sub,
    req.params.patientUserId,
    data,
  );
  res.status(201).json({ ok: true, data: result });
});

// Handles the "update treatment plan" endpoint and returns the service response.
const updateTreatmentPlan = asyncHandler(async (req, res) => {
  const data = updateTreatmentPlanSchema.parse(req.body);
  const result = await service.updateTreatmentPlan(
    req.user.sub,
    req.params.patientUserId,
    req.params.planId,
    data,
  );
  res.json({ ok: true, data: result });
});

// Handles the "get my history record" endpoint and returns the service response.
const getMyHistoryRecord = asyncHandler(async (req, res) => {
  const result = await service.getMyHistoryRecord(req.user.sub);
  res.json({ ok: true, data: result });
});

// Handles the "list my history records" endpoint and returns the service response.
const listMyHistoryRecords = asyncHandler(async (req, res) => {
  const result = await service.listMyHistoryRecords(req.user.sub);
  res.json({ ok: true, data: result });
});

// Handles the "create my history record" endpoint and returns the service response.
const createMyHistoryRecord = asyncHandler(async (req, res) => {
  const result = await withHistoryRecordPayload(
    req,
    createHistoryRecordSchema,
    (data) => service.createMyHistoryRecord(req.user.sub, data),
  );
  res.status(201).json({ ok: true, data: result });
});

// Handles the "request my history record update" endpoint and returns the service response.
const requestMyHistoryRecordUpdate = asyncHandler(async (req, res) => {
  const result = await withHistoryRecordPayload(
    req,
    requestHistoryRecordUpdateSchema,
    (data) => service.requestMyHistoryRecordUpdate(req.user.sub, data),
  );
  res.json({ ok: true, data: result });
});

// Handles the "get patient history record" endpoint and returns the service response.
const getPatientHistoryRecord = asyncHandler(async (req, res) => {
  const result = await service.getPatientHistoryRecord(
    req.user.sub,
    req.params.patientUserId,
  );
  res.json({ ok: true, data: result });
});

// Handles the "list patient history records" endpoint and returns the service response.
const listPatientHistoryRecords = asyncHandler(async (req, res) => {
  const result = await service.listPatientHistoryRecords(
    req.user.sub,
    req.params.patientUserId,
  );
  res.json({ ok: true, data: result });
});

// Handles the "create patient history record" endpoint and returns the service response.
const createPatientHistoryRecord = asyncHandler(async (req, res) => {
  const result = await withHistoryRecordPayload(
    req,
    updateHistoryRecordByDoctorSchema,
    (data) => service.createPatientHistoryRecord(
      req.user.sub,
      req.params.patientUserId,
      data,
    ),
  );
  res.status(201).json({ ok: true, data: result });
});

// Handles the "update patient history record" endpoint and returns the service response.
const updatePatientHistoryRecord = asyncHandler(async (req, res) => {
  const result = await withHistoryRecordPayload(
    req,
    updateHistoryRecordByDoctorSchema,
    (data) => service.updatePatientHistoryRecord(
      req.user.sub,
      req.params.patientUserId,
      data,
    ),
  );
  res.json({ ok: true, data: result });
});

// Handles the "update doctor-created patient from care namespace" endpoint.
const updateCreatedPatient = asyncHandler(async (req, res) => {
  const data = updateDoctorCreatedPatientSchema.parse(req.body);
  const result = await service.updateCreatedPatient(
    req.user.sub,
    req.params.patientId,
    data,
  );
  res.json({ ok: true, data: result });
});

// Handles the "delete doctor-created patient from care namespace" endpoint.
const deleteCreatedPatient = asyncHandler(async (req, res) => {
  const result = await service.deleteCreatedPatient(
    req.user.sub,
    req.params.patientId,
  );
  res.json({ ok: true, data: result });
});

// Handles the "list doctor history update requests" endpoint and returns the service response.
const listDoctorHistoryUpdateRequests = asyncHandler(async (req, res) => {
  const result = await service.listDoctorHistoryUpdateRequests(req.user.sub);
  res.json({ ok: true, data: result });
});

// Handles the "respond history update request" endpoint and returns the service response.
const respondHistoryUpdateRequest = asyncHandler(async (req, res) => {
  const { action } = respondHistoryUpdateRequestSchema.parse(req.body);
  const result = await service.respondHistoryUpdateRequest(
    req.user.sub,
    req.params.requestId,
    action,
  );
  res.json({ ok: true, data: result });
});

module.exports = {
  listMyTreatmentPlans,
  getMyLatestTreatmentPlan,
  listPatientTreatmentPlans,
  getPatientLatestTreatmentPlan,
  createTreatmentPlan,
  createPatientTreatmentPlan,
  updateTreatmentPlan,
  getMyHistoryRecord,
  listMyHistoryRecords,
  createMyHistoryRecord,
  requestMyHistoryRecordUpdate,
  getPatientHistoryRecord,
  listPatientHistoryRecords,
  createPatientHistoryRecord,
  updatePatientHistoryRecord,
  updateCreatedPatient,
  deleteCreatedPatient,
  listDoctorHistoryUpdateRequests,
  respondHistoryUpdateRequest,
};
