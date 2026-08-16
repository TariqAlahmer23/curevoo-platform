// Handles doctor profile, settings, photo, and QR persistence.
const prisma = require("../../prisma/client");

const doctorProfileSelect = {
  id: true,
  userId: true,
  fullName: true,
  specialization: true,
  workingAt: true,
  languages: true,
  location: true,
  qualifications: true,
  experience: true,
  bio: true,
  photoUrl: true,
  qrCode: true,
  consultationFee: true,
  isActive: true,
  createdAt: true,
  updatedAt: true,
  user: {
    select: {
      id: true,
      email: true,
      name: true,
      phoneNumber: true,
      age: true,
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

const linkedPatientSummarySelect = {
  id: true,
  email: true,
  name: true,
  age: true,
  phoneNumber: true,
  patientProfile: {
    select: {
      fullName: true,
      age: true,
      sex: true,
      medicalHistory: true,
    },
  },
  medicalHistories: {
    orderBy: { updatedAt: "desc" },
    take: 1,
    select: {
      id: true,
      record: true,
      updatedAt: true,
    },
  },
  treatmentRecords: {
    orderBy: { updatedAt: "desc" },
    take: 1,
    select: {
      id: true,
      curevooDetectorResult: true,
      updatedAt: true,
    },
  },
  cancerResistances: {
    orderBy: { createdAt: "desc" },
    take: 1,
    select: {
      id: true,
      aiResult: true,
      createdAt: true,
    },
  },
};

// Executes the database operation for "get doctor profile by user id".
async function getDoctorProfileByUserId(userId) {
  return prisma.doctorProfile.findUnique({
    where: { userId },
    select: doctorProfileSelect,
  });
}

// Executes the database operation for "update doctor profile".
async function updateDoctorProfile(userId, data) {
  const {
    fullName,
    phoneNumber,
    age,
    specialization,
    workingAt,
    languages,
    location,
    qualifications,
    experience,
    bio,
    consultationFee,
  } = data;

  return prisma.$transaction(async (tx) => {
    if (
      fullName !== undefined ||
      phoneNumber !== undefined ||
      age !== undefined
    ) {
      await tx.user.update({
        where: { id: userId },
        data: {
          name: fullName ?? undefined,
          phoneNumber: phoneNumber ?? undefined,
          age: age ?? undefined,
        },
      });
    }

    return tx.doctorProfile.update({
      where: { userId },
      data: {
        fullName: fullName ?? undefined,
        specialization: specialization ?? undefined,
        workingAt: workingAt ?? undefined,
        languages: languages ?? undefined,
        location: location ?? undefined,
        qualifications: qualifications ?? undefined,
        experience: experience ?? undefined,
        bio: bio ?? undefined,
        consultationFee: consultationFee ?? undefined,
      },
      select: doctorProfileSelect,
    });
  });
}

// Executes the database operation for "get doctor settings by user id".
async function getDoctorSettingsByUserId(userId) {
  return prisma.doctorSettings.findUnique({
    where: { userId },
    select: {
      id: true,
      language: true,
      notificationsEnabled: true,
      createdAt: true,
      updatedAt: true,
    },
  });
}

// Executes the database operation for "update doctor settings".
async function updateDoctorSettings(userId, data) {
  return prisma.doctorSettings.update({
    where: { userId },
    data,
    select: {
      id: true,
      language: true,
      notificationsEnabled: true,
      createdAt: true,
      updatedAt: true,
    },
  });
}

// Executes the database operation for "update doctor photo url".
async function updateDoctorPhotoUrl(userId, photoUrl) {
  return prisma.doctorProfile.update({
    where: { userId },
    data: { photoUrl },
    select: {
      photoUrl: true,
    },
  });
}

// Executes the database operation for "update doctor qr code".
async function updateDoctorQrCode(userId, qrCode) {
  return prisma.doctorProfile.update({
    where: { userId },
    data: { qrCode },
    select: {
      qrCode: true,
    },
  });
}

// Executes the database operation for "list linked patients for doctor summaries".
async function listDoctorLinkedPatients(doctorUserId) {
  return prisma.doctorPatientLink.findMany({
    where: {
      doctorUserId,
      status: "ACTIVE",
    },
    orderBy: { createdAt: "desc" },
    select: {
      id: true,
      createdAt: true,
      updatedAt: true,
      patient: {
        select: linkedPatientSummarySelect,
      },
    },
  });
}

// Executes the database operation for "list created patients for doctor summaries".
async function listDoctorCreatedPatients(doctorUserId) {
  return prisma.createdPatient.findMany({
    where: { doctorUserId },
    orderBy: { createdAt: "desc" },
    select: {
      id: true,
      sourcePatientUserId: true,
      fullName: true,
      phoneNumber: true,
      age: true,
      sex: true,
      medicalHistory: true,
      createdAt: true,
    },
  });
}

// Executes the database operation for "find active linked patient by id for doctor".
async function findDoctorLinkedPatientById(doctorUserId, patientUserId) {
  return prisma.doctorPatientLink.findFirst({
    where: {
      doctorUserId,
      patientUserId,
      status: "ACTIVE",
    },
    select: {
      id: true,
      patient: {
        select: {
          id: true,
          email: true,
          name: true,
          age: true,
          phoneNumber: true,
          createdAt: true,
          updatedAt: true,
          patientProfile: {
            select: {
              id: true,
              fullName: true,
              sex: true,
              medicalHistory: true,
              riskFactors: true,
              age: true,
              address: true,
              createdAt: true,
              updatedAt: true,
            },
          },
        },
      },
    },
  });
}

// Executes the database operation for "find created patient by id for doctor".
async function findDoctorCreatedPatientById(doctorUserId, createdPatientId) {
  return prisma.createdPatient.findFirst({
    where: {
      id: createdPatientId,
      doctorUserId,
    },
    select: {
      id: true,
      sourcePatientUserId: true,
      doctorUserId: true,
      fullName: true,
      phoneNumber: true,
      age: true,
      sex: true,
      medicalHistory: true,
      riskFactors: true,
      createdAt: true,
    },
  });
}

// Executes the database operation for "update created patient by id for doctor".
async function updateDoctorCreatedPatientById(createdPatientId, data) {
  return prisma.createdPatient.update({
    where: { id: createdPatientId },
    data: {
      fullName: data.fullName ?? undefined,
      phoneNumber: data.phoneNumber ?? undefined,
      age: data.age ?? undefined,
      sex: data.sex ?? undefined,
      medicalHistory: data.medicalHistory ?? undefined,
      riskFactors: data.riskFactors ?? undefined,
    },
    select: {
      id: true,
      sourcePatientUserId: true,
      doctorUserId: true,
      fullName: true,
      phoneNumber: true,
      age: true,
      sex: true,
      medicalHistory: true,
      riskFactors: true,
      createdAt: true,
    },
  });
}

// Executes the database operation for "delete created patient by id for doctor".
async function deleteDoctorCreatedPatientById(createdPatientId) {
  return prisma.createdPatient.delete({
    where: { id: createdPatientId },
    select: {
      id: true,
      sourcePatientUserId: true,
      doctorUserId: true,
    },
  });
}

// Executes the database operation for "get latest medical history for patient".
async function getLatestMedicalHistoryForPatient(patientUserId) {
  return prisma.medicalHistory.findFirst({
    where: { patientUserId },
    orderBy: { updatedAt: "desc" },
    select: medicalHistorySelect,
  });
}

// Executes the database operation for "list medical histories for patient".
async function listMedicalHistoriesForPatient(patientUserId) {
  return prisma.medicalHistory.findMany({
    where: { patientUserId },
    orderBy: [{ updatedAt: "desc" }, { createdAt: "desc" }],
    select: medicalHistorySelect,
  });
}

// Executes the database operation for "get latest medical history for doctor subject".
async function getLatestMedicalHistoryForSubject({ patientUserId, createdPatientId }) {
  return prisma.medicalHistory.findFirst({
    where: {
      patientUserId: patientUserId ?? undefined,
      createdPatientId: createdPatientId ?? undefined,
    },
    orderBy: { updatedAt: "desc" },
    select: medicalHistorySelect,
  });
}

// Executes the database operation for "list medical histories for doctor subject".
async function listMedicalHistoriesForSubject({ patientUserId, createdPatientId }) {
  return prisma.medicalHistory.findMany({
    where: {
      patientUserId: patientUserId ?? undefined,
      createdPatientId: createdPatientId ?? undefined,
    },
    orderBy: [{ updatedAt: "desc" }, { createdAt: "desc" }],
    select: medicalHistorySelect,
  });
}

// Executes the database operation for "get latest medical record for patient".
async function getLatestMedicalRecordForPatient(patientUserId) {
  return prisma.treatmentRecord.findFirst({
    where: { patientUserId },
    orderBy: [{ updatedAt: "desc" }, { createdAt: "desc" }],
    select: {
      id: true,
      patientUserId: true,
      curevooDetectorResult: true,
      record: true,
      createdAt: true,
      updatedAt: true,
    },
  });
}

// Executes the database operation for "list medical records for patient".
async function listMedicalRecordsForPatient(patientUserId) {
  return prisma.treatmentRecord.findMany({
    where: { patientUserId },
    orderBy: { updatedAt: "desc" },
    select: {
      id: true,
      patientUserId: true,
      curevooDetectorResult: true,
      record: true,
      createdAt: true,
      updatedAt: true,
    },
  });
}

// Executes the database operation for "get latest treatment plan for doctor patient".
async function getLatestTreatmentPlanForDoctorPatient(doctorUserId, patientUserId) {
  return prisma.treatmentPlan.findFirst({
    where: {
      doctorUserId,
      patientUserId,
    },
    orderBy: [{ updatedAt: "desc" }, { createdAt: "desc" }],
    select: treatmentPlanSelect,
  });
}

// Executes the database operation for "list treatment plans for doctor patient".
async function listTreatmentPlansForDoctorPatient(doctorUserId, patientUserId) {
  return prisma.treatmentPlan.findMany({
    where: {
      doctorUserId,
      patientUserId,
    },
    orderBy: { createdAt: "desc" },
    select: treatmentPlanSelect,
  });
}

// Executes the database operation for "get latest treatment plan for doctor subject".
async function getLatestTreatmentPlanForDoctorSubject(
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
    select: treatmentPlanSelect,
  });
}

// Executes the database operation for "list treatment plans for doctor subject".
async function listTreatmentPlansForDoctorSubject(
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
    select: treatmentPlanSelect,
  });
}

// Executes the database operation for "get doctor dashboard summary counts".
async function getDoctorDashboardSummary(doctorUserId) {
  const now = new Date();

  const [
    linkedPatientsCount,
    createdPatientsCount,
    upcomingAppointmentsCount,
    pendingAppointmentsCount,
    latestNormalPrediction,
    latestCreatedPrediction,
  ] = await Promise.all([
    prisma.doctorPatientLink.count({
      where: { doctorUserId, status: "ACTIVE" },
    }),
    prisma.createdPatient.count({
      where: { doctorUserId },
    }),
    prisma.appointment.count({
      where: {
        doctorUserId,
        scheduledAt: { gte: now },
        status: { in: ["PENDING", "CREATED", "CONFIRMED"] },
      },
    }),
    prisma.appointment.count({
      where: {
        doctorUserId,
        status: "PENDING",
      },
    }),
    prisma.aiNsclcPredictionRun.findFirst({
      where: {
        doctorId: doctorUserId,
        status: "SUCCESS",
      },
      orderBy: [{ createdAt: "desc" }],
      select: { createdAt: true },
    }),
    prisma.aiNsclcPredictionRunCreated.findFirst({
      where: {
        doctorId: doctorUserId,
        status: "SUCCESS",
      },
      orderBy: [{ createdAt: "desc" }],
      select: { createdAt: true },
    }),
  ]);

  const latestAiPredictionAt = [latestNormalPrediction?.createdAt, latestCreatedPrediction?.createdAt]
    .filter(Boolean)
    .sort((left, right) => new Date(right) - new Date(left))[0] || null;

  return {
    totalPatients: linkedPatientsCount + createdPatientsCount,
    linkedPatients: linkedPatientsCount,
    createdPatients: createdPatientsCount,
    upcomingAppointments: upcomingAppointmentsCount,
    pendingAppointments: pendingAppointmentsCount,
    latestAiPredictionAt,
  };
}

module.exports = {
  getDoctorProfileByUserId,
  updateDoctorProfile,
  getDoctorSettingsByUserId,
  updateDoctorSettings,
  updateDoctorPhotoUrl,
  updateDoctorQrCode,
  listDoctorLinkedPatients,
  listDoctorCreatedPatients,
  findDoctorLinkedPatientById,
  findDoctorCreatedPatientById,
  updateDoctorCreatedPatientById,
  deleteDoctorCreatedPatientById,
  getLatestMedicalHistoryForPatient,
  listMedicalHistoriesForPatient,
  getLatestMedicalHistoryForSubject,
  listMedicalHistoriesForSubject,
  getLatestMedicalRecordForPatient,
  listMedicalRecordsForPatient,
  getLatestTreatmentPlanForDoctorPatient,
  listTreatmentPlansForDoctorPatient,
  getLatestTreatmentPlanForDoctorSubject,
  listTreatmentPlansForDoctorSubject,
  getDoctorDashboardSummary,
};
