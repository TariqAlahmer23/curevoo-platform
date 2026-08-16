// Handles patient profile, test record, and AI result persistence.
const { prisma } = require("../../prisma/client");

const patientProfileSelect = {
  id: true,
  userId: true,
  fullName: true,
  address: true,
  age: true,
  sex: true,
  phoneNumber: true,
  medicalHistory: true,
  riskFactors: true,
  qrCode: true,
  createdAt: true,
  updatedAt: true,
  user: {
    select: {
      id: true,
      email: true,
      role: true,
      name: true,
      phoneNumber: true,
      age: true,
    },
  },
};

// Executes the database operation for "get patient me".
async function getPatientMe(userId) {
  return prisma.patientProfile.findUnique({
    where: { userId },
    select: patientProfileSelect,
  });
}

// Executes the database operation for "update patient me".
async function updatePatientMe(userId, data) {
  const {
    fullName,
    phoneNumber,
    age,
    address,
    location,
    sex,
    medicalHistory,
    riskFactors,
  } = data;
  const resolvedAddress = address ?? location;

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

    return tx.patientProfile.update({
      where: { userId },
      data: {
        fullName: fullName ?? undefined,
        address: resolvedAddress ?? undefined,
        age: age ?? undefined,
        sex: sex ?? undefined,
        medicalHistory: medicalHistory ?? undefined,
        riskFactors: riskFactors ?? undefined,
      },
      select: patientProfileSelect,
    });
  });
}

// Executes the database operation for "create test record with resistance".
async function createTestRecordWithResistance(patientUserId, data) {
  return prisma.$transaction(async (tx) => {
    const createdRecord = await tx.testRecord.create({
      data: {
        patientUserId,
        recordDate: data.recordDate ?? undefined,
        recordTitle: data.recordTitle ?? null,
        testRecordData: data.testRecordData ?? undefined,
      },
      select: {
        id: true,
        patientUserId: true,
        recordDate: true,
        recordTitle: true,
        testRecordData: true,
        createdAt: true,
      },
    });

    const numberOfRecords = await tx.testRecord.count({
      where: { patientUserId },
    });

    const resistanceSnapshot = await tx.cancerResistance.create({
      data: {
        patientUserId,
        testRecordId: createdRecord.id,
        numberOfRecords,
        aiResult: data.aiResult ?? null,
        lastAdd: createdRecord.recordDate,
      },
      select: {
        id: true,
        numberOfRecords: true,
        aiResult: true,
        lastAdd: true,
        createdAt: true,
      },
    });

    return {
      testRecord: createdRecord,
      resistanceSnapshot,
    };
  });
}

// Executes the database operation for "list patient ai results".
function listPatientAiResults(patientUserId) {
  return prisma.cancerResistance.findMany({
    where: { patientUserId },
    orderBy: { createdAt: "desc" },
    select: {
      id: true,
      numberOfRecords: true,
      aiResult: true,
      lastAdd: true,
      createdAt: true,
      testRecord: {
        select: {
          id: true,
          recordDate: true,
          recordTitle: true,
          testRecordData: true,
          createdAt: true,
        },
      },
    },
  });
}

// Executes the database operation for "create doctor created patient".
function createCreatedPatient({
  doctorUserId,
  fullName,
  phoneNumber,
  age,
  sex,
  medicalHistory,
  riskFactors,
}) {
  return prisma.createdPatient.create({
    data: {
      doctorUserId,
      fullName: fullName ?? null,
      phoneNumber: phoneNumber ?? null,
      age: age ?? null,
      sex: sex ?? null,
      medicalHistory: medicalHistory ?? null,
      riskFactors: riskFactors ?? null,
    },
  });
}

// Executes the database operation for "list doctor created patients".
function listDoctorCreatedPatients(doctorUserId) {
  return prisma.createdPatient.findMany({
    where: { doctorUserId },
    orderBy: { createdAt: "desc" },
  });
}

// Executes the database operation for "create created patient snapshot from profile".
function createCreatedPatientFromProfile({
  doctorUserId,
  patientUserId,
  profile,
}) {
  return prisma.createdPatient.upsert({
    where: {
      doctorUserId_sourcePatientUserId: {
        doctorUserId,
        sourcePatientUserId: patientUserId,
      },
    },
    create: {
      doctorUserId,
      sourcePatientUserId: patientUserId,
      fullName: profile?.fullName || null,
      phoneNumber: profile?.phoneNumber || null,
      age: profile?.age || null,
      sex: profile?.sex || null,
      medicalHistory: profile?.medicalHistory || null,
      riskFactors: profile?.riskFactors || null,
    },
    update: {
      fullName: profile?.fullName || null,
      phoneNumber: profile?.phoneNumber || null,
      age: profile?.age || null,
      sex: profile?.sex || null,
      medicalHistory: profile?.medicalHistory || null,
      riskFactors: profile?.riskFactors || null,
    },
  });
}

// Executes the database operation for "count upcoming appointments for patient dashboard".
function countUpcomingAppointmentsForPatient(patientUserId) {
  return prisma.appointment.count({
    where: {
      patientUserId,
      scheduledAt: { gte: new Date() },
      status: { in: ["PENDING", "CREATED", "CONFIRMED"] },
    },
  });
}

// Executes the database operation for "get latest successful patient NSCLC prediction run".
function getLatestSuccessfulNsclcPredictionForPatient(patientUserId) {
  return prisma.aiNsclcPredictionRun.findFirst({
    where: {
      patientId: patientUserId,
      status: "SUCCESS",
    },
    orderBy: [{ createdAt: "desc" }],
    select: {
      id: true,
      predictionVersion: true,
      summaryText: true,
      earlyFailureProbability: true,
      earlyFailureRiskLevel: true,
      durableBenefitProbability: true,
      durableBenefitRiskLevel: true,
      interpretationSummary: true,
      createdAt: true,
    },
  });
}

module.exports = {
  getPatientMe,
  updatePatientMe,
  createTestRecordWithResistance,
  listPatientAiResults,
  createCreatedPatient,
  listDoctorCreatedPatients,
  createCreatedPatientFromProfile,
  countUpcomingAppointmentsForPatient,
  getLatestSuccessfulNsclcPredictionForPatient,
};
