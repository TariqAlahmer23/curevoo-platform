// Implements treatment plan and medical history workflows with doctor-patient access checks.
const { AppError } = require("../../common/errors/AppError");
const repo = require("./care.repo");
const doctorService = require("../doctors/doctor.service");

// Resolves whether the doctor is targeting a linked real patient or a doctor-created patient.
async function resolveDoctorCareSubject(doctorUserId, patientId) {
  const link = await repo.findActiveDoctorPatientLink(doctorUserId, patientId);
  if (link) {
    return {
      subjectType: "NORMAL",
      patientUserId: patientId,
      createdPatientId: null,
    };
  }

  const createdPatient = await repo.findDoctorCreatedPatientById(
    doctorUserId,
    patientId,
  );
  if (createdPatient) {
    return {
      subjectType: "CREATED",
      patientUserId: null,
      createdPatientId: patientId,
    };
  }

  const patient = await repo.findPatientUserById(patientId);
  if (patient) {
    throw new AppError(
      "Doctor is not linked to this patient",
      403,
      "PATIENT_NOT_LINKED",
    );
  }

  throw new AppError("Patient not found", 404, "PATIENT_NOT_FOUND");
}

function doesPlanBelongToSubject(plan, subject) {
  return (
    (subject.patientUserId && plan.patientUserId === subject.patientUserId) ||
    (subject.createdPatientId && plan.createdPatientId === subject.createdPatientId)
  );
}

// Executes the "list my treatment plans" business workflow for this module.
async function listMyTreatmentPlans(patientUserId) {
  return repo.listTreatmentPlansForPatient(patientUserId);
}

// Executes the "get my latest treatment plan" business workflow for this module.
async function getMyLatestTreatmentPlan(patientUserId) {
  return repo.getLatestTreatmentPlanForPatient(patientUserId);
}

// Executes the "list patient treatment plans" business workflow for this module.
async function listPatientTreatmentPlans(doctorUserId, patientId) {
  const subject = await resolveDoctorCareSubject(doctorUserId, patientId);
  return repo.listTreatmentPlansForDoctorSubject(doctorUserId, subject);
}

// Executes the "get patient latest treatment plan" business workflow for this module.
async function getPatientLatestTreatmentPlan(doctorUserId, patientId) {
  const subject = await resolveDoctorCareSubject(doctorUserId, patientId);
  return repo.getLatestTreatmentPlanForDoctorSubject(doctorUserId, subject);
}

// Executes the "create treatment plan" business workflow for this module.
async function createTreatmentPlan(doctorUserId, data) {
  const subject = await resolveDoctorCareSubject(doctorUserId, data.patientId);
  return repo.createTreatmentPlan({
    doctorUserId,
    patientUserId: subject.patientUserId,
    createdPatientId: subject.createdPatientId,
    treatmentPlan: data.treatmentPlan,
    symptomsLog: data.symptomsLog,
  });
}

// Executes the "create patient treatment plan by route id" business workflow.
async function createPatientTreatmentPlan(doctorUserId, patientId, data) {
  return createTreatmentPlan(doctorUserId, {
    patientId,
    treatmentPlan: data.treatmentPlan,
    symptomsLog: data.symptomsLog,
  });
}

// Executes the "update treatment plan" business workflow for this module.
async function updateTreatmentPlan(doctorUserId, patientId, planId, data) {
  const subject = await resolveDoctorCareSubject(doctorUserId, patientId);

  const plan = await repo.findTreatmentPlanById(planId);
  if (!plan) {
    throw new AppError("Treatment plan not found", 404, "TREATMENT_PLAN_NOT_FOUND");
  }

  if (plan.doctorUserId !== doctorUserId || !doesPlanBelongToSubject(plan, subject)) {
    throw new AppError("Forbidden", 403, "FORBIDDEN");
  }

  return repo.updateTreatmentPlanById(planId, data);
}

// Executes the "get my history record" business workflow for this module.
async function getMyHistoryRecord(patientUserId) {
  return repo.getLatestMedicalHistory(patientUserId);
}

// Executes the "list my history records" business workflow for this module.
async function listMyHistoryRecords(patientUserId) {
  return repo.listMedicalHistoriesForPatient(patientUserId);
}

// Executes the "create my history record" business workflow for this module.
async function createMyHistoryRecord(patientUserId, data) {
  const existing = await repo.getLatestMedicalHistory(patientUserId);
  if (existing) {
    throw new AppError(
      "History record already exists. Use update request.",
      409,
      "HISTORY_ALREADY_EXISTS",
    );
  }

  return repo.createMedicalHistory({ patientUserId }, data.record);
}

// Executes the "request my history record update" business workflow for this module.
async function requestMyHistoryRecordUpdate(patientUserId, data) {
  const subject = await resolveDoctorCareSubject(data.doctorUserId, patientUserId);
  if (subject.subjectType !== "NORMAL") {
    throw new AppError(
      "Doctor is not linked to this patient",
      403,
      "PATIENT_NOT_LINKED",
    );
  }

  const existing = await repo.getLatestMedicalHistory(patientUserId);
  if (!existing) {
    const created = await repo.createMedicalHistory({ patientUserId }, data.record);
    return {
      createdDirectly: true,
      historyRecord: created,
    };
  }

  const request = await repo.upsertMedicalHistoryUpdateRequest({
    medicalHistoryId: existing.id,
    doctorUserId: data.doctorUserId,
    patientUserId,
    proposedRecord: data.record,
  });

  return {
    createdDirectly: false,
    request,
  };
}

// Executes the "get patient history record" business workflow for this module.
async function getPatientHistoryRecord(doctorUserId, patientId) {
  const subject = await resolveDoctorCareSubject(doctorUserId, patientId);
  return repo.getLatestMedicalHistoryBySubject(subject);
}

// Executes the "list patient history records" business workflow for this module.
async function listPatientHistoryRecords(doctorUserId, patientId) {
  const subject = await resolveDoctorCareSubject(doctorUserId, patientId);
  return repo.listMedicalHistoriesBySubject(subject);
}

// Executes the "create patient history record" business workflow for this module.
async function createPatientHistoryRecord(doctorUserId, patientId, data) {
  const subject = await resolveDoctorCareSubject(doctorUserId, patientId);
  return repo.createMedicalHistory(subject, data.record);
}

// Executes the "update patient history record" business workflow for this module.
async function updatePatientHistoryRecord(doctorUserId, patientId, data) {
  const subject = await resolveDoctorCareSubject(doctorUserId, patientId);

  const existing = await repo.getLatestMedicalHistoryBySubject(subject);
  if (!existing) {
    return repo.createMedicalHistory(subject, data.record);
  }

  return repo.updateMedicalHistoryById(existing.id, data.record);
}

// Executes the "update doctor-created patient from care namespace" workflow.
async function updateCreatedPatient(doctorUserId, patientId, data) {
  return doctorService.updatePatient(doctorUserId, patientId, data);
}

// Executes the "delete doctor-created patient from care namespace" workflow.
async function deleteCreatedPatient(doctorUserId, patientId) {
  return doctorService.deletePatient(doctorUserId, patientId);
}

// Executes the "list doctor history update requests" business workflow for this module.
async function listDoctorHistoryUpdateRequests(doctorUserId) {
  return repo.listHistoryUpdateRequestsByDoctor(doctorUserId);
}

// Executes the "respond history update request" business workflow for this module.
async function respondHistoryUpdateRequest(doctorUserId, requestId, action) {
  const request = await repo.findHistoryUpdateRequestById(requestId);
  if (!request) {
    throw new AppError("History update request not found", 404, "REQUEST_NOT_FOUND");
  }

  if (request.doctorUserId !== doctorUserId) {
    throw new AppError("Forbidden", 403, "FORBIDDEN");
  }

  if (request.status !== "PENDING") {
    throw new AppError(
      "History update request already handled",
      400,
      "REQUEST_ALREADY_RESOLVED",
    );
  }

  if (action === "APPROVE") {
    const approved = await repo.approveHistoryUpdateRequest(requestId);
    return { status: approved?.status || "APPROVED", requestId };
  }

  const rejected = await repo.updateHistoryUpdateRequestStatus(requestId, "REJECTED");
  return { status: rejected.status, requestId };
}

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
