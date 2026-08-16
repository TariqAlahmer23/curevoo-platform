// Handles treatment plan and medical history persistence.
const { prisma } = require("../../prisma/client");

const treatmentPlanSelect = {
  id: true,
  doctorUserId: true,
  patientUserId: true,
  createdPatientId: true,
  symptomsLog: true,
  treatmentPlan: true,
  createdAt: true,
  updatedAt: true,
};

const treatmentPlanPatientSelect = {
  ...treatmentPlanSelect,
  doctor: {
    select: {
      id: true,
      email: true,
      doctorProfile: { select: { fullName: true, specialization: true } },
    },
  },
};

const treatmentPlanDoctorSelect = {
  ...treatmentPlanSelect,
  patient: {
    select: {
      id: true,
      email: true,
      patientProfile: { select: { fullName: true } },
    },
  },
  createdPatient: {
    select: {
      id: true,
      fullName: true,
    },
  },
};

const medicalHistorySelect = {
  id: true,
  patientUserId: true,
  createdPatientId: true,
  record: true,
  createdAt: true,
  updatedAt: true,
};

// Executes the database operation for "find active doctor patient link".
function findActiveDoctorPatientLink(doctorUserId, patientUserId) {
  return prisma.doctorPatientLink.findFirst({
    where: {
      doctorUserId,
      patientUserId,
      status: "ACTIVE",
    },
  });
}

// Executes the database operation for "find patient user by id".
function findPatientUserById(id) {
  return prisma.user.findFirst({
    where: {
      id,
      role: "PATIENT",
    },
    select: {
      id: true,
    },
  });
}

// Executes the database operation for "find doctor-created patient by id".
function findDoctorCreatedPatientById(doctorUserId, createdPatientId) {
  return prisma.createdPatient.findFirst({
    where: {
      id: createdPatientId,
      doctorUserId,
    },
    select: {
      id: true,
      doctorUserId: true,
      sourcePatientUserId: true,
      fullName: true,
      createdAt: true,
    },
  });
}

// Executes the database operation for "list treatment plans for patient".
function listTreatmentPlansForPatient(patientUserId) {
  return prisma.treatmentPlan.findMany({
    where: { patientUserId },
    orderBy: { createdAt: "desc" },
    select: treatmentPlanPatientSelect,
  });
}

// Executes the database operation for "get latest treatment plan for patient".
function getLatestTreatmentPlanForPatient(patientUserId) {
  return prisma.treatmentPlan.findFirst({
    where: { patientUserId },
    orderBy: [{ updatedAt: "desc" }, { createdAt: "desc" }],
    select: treatmentPlanPatientSelect,
  });
}

// Executes the database operation for "list treatment plans for doctor subject".
function listTreatmentPlansForDoctorSubject(
  doctorUserId,
  { patientUserId, createdPatientId },
) {
  return prisma.treatmentPlan.findMany({
    where: {
      doctorUserId,
      patientUserId: patientUserId ?? undefined,
      createdPatientId: createdPatientId ?? undefined,
    },
    orderBy: { createdAt: "desc" },
    select: treatmentPlanDoctorSelect,
  });
}

// Executes the database operation for "get latest treatment plan for doctor subject".
function getLatestTreatmentPlanForDoctorSubject(
  doctorUserId,
  { patientUserId, createdPatientId },
) {
  return prisma.treatmentPlan.findFirst({
    where: {
      doctorUserId,
      patientUserId: patientUserId ?? undefined,
      createdPatientId: createdPatientId ?? undefined,
    },
    orderBy: [{ updatedAt: "desc" }, { createdAt: "desc" }],
    select: treatmentPlanDoctorSelect,
  });
}

// Executes the database operation for "create treatment plan".
function createTreatmentPlan({
  doctorUserId,
  patientUserId,
  createdPatientId,
  treatmentPlan,
  symptomsLog,
}) {
  return prisma.treatmentPlan.create({
    data: {
      doctorUserId,
      patientUserId: patientUserId ?? undefined,
      createdPatientId: createdPatientId ?? undefined,
      treatmentPlan,
      symptomsLog: symptomsLog ?? undefined,
    },
    select: treatmentPlanSelect,
  });
}

// Executes the database operation for "find treatment plan by id".
function findTreatmentPlanById(id) {
  return prisma.treatmentPlan.findUnique({
    where: { id },
  });
}

// Executes the database operation for "update treatment plan by id".
function updateTreatmentPlanById(id, data) {
  return prisma.treatmentPlan.update({
    where: { id },
    data: {
      treatmentPlan: data.treatmentPlan ?? undefined,
      symptomsLog: data.symptomsLog ?? undefined,
    },
    select: treatmentPlanSelect,
  });
}

// Executes the database operation for "get latest medical history".
function getLatestMedicalHistory(patientUserId) {
  return prisma.medicalHistory.findFirst({
    where: { patientUserId },
    orderBy: { updatedAt: "desc" },
    select: medicalHistorySelect,
  });
}

// Executes the database operation for "list medical histories for patient".
function listMedicalHistoriesForPatient(patientUserId) {
  return prisma.medicalHistory.findMany({
    where: { patientUserId },
    orderBy: [{ updatedAt: "desc" }, { createdAt: "desc" }],
    select: medicalHistorySelect,
  });
}

// Executes the database operation for "get latest medical history by subject".
function getLatestMedicalHistoryBySubject({ patientUserId, createdPatientId }) {
  return prisma.medicalHistory.findFirst({
    where: {
      patientUserId: patientUserId ?? undefined,
      createdPatientId: createdPatientId ?? undefined,
    },
    orderBy: { updatedAt: "desc" },
    select: medicalHistorySelect,
  });
}

// Executes the database operation for "list medical histories by subject".
function listMedicalHistoriesBySubject({ patientUserId, createdPatientId }) {
  return prisma.medicalHistory.findMany({
    where: {
      patientUserId: patientUserId ?? undefined,
      createdPatientId: createdPatientId ?? undefined,
    },
    orderBy: [{ updatedAt: "desc" }, { createdAt: "desc" }],
    select: medicalHistorySelect,
  });
}

// Executes the database operation for "create medical history".
function createMedicalHistory(subject, record) {
  return prisma.medicalHistory.create({
    data: {
      patientUserId: subject.patientUserId ?? undefined,
      createdPatientId: subject.createdPatientId ?? undefined,
      record,
    },
    select: medicalHistorySelect,
  });
}

// Executes the database operation for "update medical history by id".
function updateMedicalHistoryById(id, record) {
  return prisma.medicalHistory.update({
    where: { id },
    data: { record },
    select: medicalHistorySelect,
  });
}

// Executes the database operation for "upsert medical history update request".
function upsertMedicalHistoryUpdateRequest({
  medicalHistoryId,
  doctorUserId,
  patientUserId,
  proposedRecord,
}) {
  return prisma.medicalHistoryUpdateRequest.upsert({
    where: {
      medicalHistoryId_doctorUserId_patientUserId: {
        medicalHistoryId,
        doctorUserId,
        patientUserId,
      },
    },
    create: {
      medicalHistoryId,
      doctorUserId,
      patientUserId,
      proposedRecord,
      status: "PENDING",
    },
    update: {
      proposedRecord,
      status: "PENDING",
      respondedAt: null,
    },
    select: {
      id: true,
      medicalHistoryId: true,
      doctorUserId: true,
      patientUserId: true,
      proposedRecord: true,
      status: true,
      createdAt: true,
      updatedAt: true,
      respondedAt: true,
    },
  });
}

// Executes the database operation for "list history update requests by doctor".
function listHistoryUpdateRequestsByDoctor(doctorUserId) {
  return prisma.medicalHistoryUpdateRequest.findMany({
    where: { doctorUserId },
    orderBy: { updatedAt: "desc" },
    include: {
      patient: {
        select: {
          id: true,
          email: true,
          patientProfile: { select: { fullName: true } },
        },
      },
      medicalHistory: {
        select: {
          id: true,
          record: true,
          updatedAt: true,
        },
      },
    },
  });
}

// Executes the database operation for "find history update request by id".
function findHistoryUpdateRequestById(id) {
  return prisma.medicalHistoryUpdateRequest.findUnique({
    where: { id },
  });
}

// Executes the database operation for "update history update request status".
function updateHistoryUpdateRequestStatus(id, status) {
  return prisma.medicalHistoryUpdateRequest.update({
    where: { id },
    data: {
      status,
      respondedAt: new Date(),
    },
  });
}

// Executes the database operation for "approve history update request".
async function approveHistoryUpdateRequest(id) {
  return prisma.$transaction(async (tx) => {
    const request = await tx.medicalHistoryUpdateRequest.findUnique({
      where: { id },
    });

    if (!request) return null;

    await tx.medicalHistory.update({
      where: { id: request.medicalHistoryId },
      data: {
        record: request.proposedRecord,
      },
    });

    return tx.medicalHistoryUpdateRequest.update({
      where: { id },
      data: {
        status: "APPROVED",
        respondedAt: new Date(),
      },
      select: {
        id: true,
        status: true,
        medicalHistoryId: true,
      },
    });
  });
}

module.exports = {
  findActiveDoctorPatientLink,
  findPatientUserById,
  findDoctorCreatedPatientById,
  listTreatmentPlansForPatient,
  getLatestTreatmentPlanForPatient,
  listTreatmentPlansForDoctorSubject,
  getLatestTreatmentPlanForDoctorSubject,
  createTreatmentPlan,
  findTreatmentPlanById,
  updateTreatmentPlanById,
  getLatestMedicalHistory,
  listMedicalHistoriesForPatient,
  getLatestMedicalHistoryBySubject,
  listMedicalHistoriesBySubject,
  createMedicalHistory,
  updateMedicalHistoryById,
  upsertMedicalHistoryUpdateRequest,
  listHistoryUpdateRequestsByDoctor,
  findHistoryUpdateRequestById,
  updateHistoryUpdateRequestStatus,
  approveHistoryUpdateRequest,
};
