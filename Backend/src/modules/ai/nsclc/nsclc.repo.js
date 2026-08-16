// Handles NSCLC AI prediction data access and persistence.
const prisma = require("../../../prisma/client");

// Loads the doctor-patient relationship plus the latest records needed for NSCLC payload mapping.
async function findDoctorAccessiblePatientContext(doctorUserId, patientId) {
  const linkedPatientContext = await prisma.doctorPatientLink.findFirst({
    where: {
      doctorUserId,
      patientUserId: patientId,
      status: "ACTIVE",
    },
    select: {
      id: true,
      doctor: {
        select: {
          id: true,
          doctorProfile: {
            select: {
              specialization: true,
              workingAt: true,
            },
          },
        },
      },
      patient: {
        select: {
          id: true,
          age: true,
          patientProfile: {
            select: {
              age: true,
              sex: true,
              medicalHistory: true,
              riskFactors: true,
            },
          },
          medicalHistories: {
            orderBy: [{ updatedAt: "desc" }, { createdAt: "desc" }],
            take: 1,
            select: {
              id: true,
              record: true,
              createdAt: true,
              updatedAt: true,
            },
          },
          treatmentPlansAsPatient: {
            where: { doctorUserId },
            orderBy: [{ updatedAt: "desc" }, { createdAt: "desc" }],
            take: 1,
            select: {
              id: true,
              symptomsLog: true,
              treatmentPlan: true,
              createdAt: true,
              updatedAt: true,
            },
          },
          treatmentRecords: {
            orderBy: [{ updatedAt: "desc" }, { createdAt: "desc" }],
            take: 1,
            select: {
              id: true,
              curevooDetectorResult: true,
              record: true,
              createdAt: true,
              updatedAt: true,
            },
          },
          testRecords: {
            orderBy: [{ recordDate: "desc" }, { createdAt: "desc" }],
            take: 1,
            select: {
              id: true,
              recordDate: true,
              recordTitle: true,
              testRecordData: true,
              createdAt: true,
            },
          },
          cancerTests: {
            orderBy: [{ testDate: "desc" }, { createdAt: "desc" }],
            take: 1,
            select: {
              id: true,
              testDate: true,
              result: true,
              testEnteredData: true,
              createdAt: true,
            },
          },
        },
      },
    },
  });

  if (linkedPatientContext?.patient) {
    return {
      subjectType: "NORMAL",
      ...linkedPatientContext,
    };
  }

  const createdPatientContext = await prisma.createdPatient.findFirst({
    where: {
      id: patientId,
      doctorUserId,
    },
    select: {
      id: true,
      sourcePatientUserId: true,
      age: true,
      sex: true,
      medicalHistory: true,
      riskFactors: true,
      doctor: {
        select: {
          id: true,
          doctorProfile: {
            select: {
              specialization: true,
              workingAt: true,
            },
          },
        },
      },
      medicalHistories: {
        orderBy: [{ updatedAt: "desc" }, { createdAt: "desc" }],
        take: 1,
        select: {
          id: true,
          record: true,
          createdAt: true,
          updatedAt: true,
        },
      },
      treatmentPlans: {
        where: { doctorUserId },
        orderBy: [{ updatedAt: "desc" }, { createdAt: "desc" }],
        take: 1,
        select: {
          id: true,
          symptomsLog: true,
          treatmentPlan: true,
          createdAt: true,
          updatedAt: true,
        },
      },
    },
  });

  if (!createdPatientContext) return null;

  return {
    subjectType: "CREATED",
    id: `created-${createdPatientContext.id}`,
    doctor: createdPatientContext.doctor,
    patient: {
      id: createdPatientContext.id,
      age: createdPatientContext.age,
      patientProfile: {
        age: createdPatientContext.age,
        sex: createdPatientContext.sex,
        medicalHistory: createdPatientContext.medicalHistory,
        riskFactors: createdPatientContext.riskFactors,
      },
      medicalHistories: createdPatientContext.medicalHistories,
      treatmentPlansAsPatient: createdPatientContext.treatmentPlans,
      treatmentRecords: [],
      testRecords: [],
      cancerTests: [],
    },
  };
}

// Stores one NSCLC prediction run for auditability and history.
async function createNsclcPredictionRun(data) {
  return prisma.aiNsclcPredictionRun.create({
    data: {
      patientId: data.patientId,
      doctorId: data.doctorId,
      predictionVersion: data.predictionVersion ?? null,
      requestPayloadJson: data.requestPayloadJson,
      responseJson: data.responseJson ?? null,
      summaryText: data.summaryText ?? null,
      earlyFailureProbability: data.earlyFailureProbability ?? null,
      earlyFailureRiskLevel: data.earlyFailureRiskLevel ?? null,
      durableBenefitProbability: data.durableBenefitProbability ?? null,
      durableBenefitRiskLevel: data.durableBenefitRiskLevel ?? null,
      interpretationSummary: data.interpretationSummary ?? null,
      llmExplanationEnabled: !!data.llmExplanationEnabled,
      status: data.status,
      errorMessage: data.errorMessage ?? null,
    },
    select: {
      id: true,
      createdAt: true,
    },
  });
}

// Stores one NSCLC prediction run for doctor-created patient subjects.
async function createNsclcPredictionRunForCreatedPatient(data) {
  return prisma.aiNsclcPredictionRunCreated.create({
    data: {
      createdPatientId: data.createdPatientId,
      doctorId: data.doctorId,
      predictionVersion: data.predictionVersion ?? null,
      requestPayloadJson: data.requestPayloadJson,
      responseJson: data.responseJson ?? null,
      summaryText: data.summaryText ?? null,
      earlyFailureProbability: data.earlyFailureProbability ?? null,
      earlyFailureRiskLevel: data.earlyFailureRiskLevel ?? null,
      durableBenefitProbability: data.durableBenefitProbability ?? null,
      durableBenefitRiskLevel: data.durableBenefitRiskLevel ?? null,
      interpretationSummary: data.interpretationSummary ?? null,
      llmExplanationEnabled: !!data.llmExplanationEnabled,
      status: data.status,
      errorMessage: data.errorMessage ?? null,
    },
    select: {
      id: true,
      createdAt: true,
    },
  });
}

// Loads the latest successful NSCLC prediction run for an active linked patient.
async function findLatestNsclcPredictionRunForPatient(doctorUserId, patientUserId) {
  return prisma.aiNsclcPredictionRun.findFirst({
    where: {
      doctorId: doctorUserId,
      patientId: patientUserId,
      status: "SUCCESS",
    },
    orderBy: [{ createdAt: "desc" }],
    select: {
      id: true,
      patientId: true,
      predictionVersion: true,
      responseJson: true,
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

// Loads the latest successful NSCLC prediction run for a doctor-created patient.
async function findLatestNsclcPredictionRunForCreatedPatient(doctorUserId, createdPatientId) {
  return prisma.aiNsclcPredictionRunCreated.findFirst({
    where: {
      doctorId: doctorUserId,
      createdPatientId,
      status: "SUCCESS",
    },
    orderBy: [{ createdAt: "desc" }],
    select: {
      id: true,
      createdPatientId: true,
      predictionVersion: true,
      responseJson: true,
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
  findDoctorAccessiblePatientContext,
  createNsclcPredictionRun,
  createNsclcPredictionRunForCreatedPatient,
  findLatestNsclcPredictionRunForPatient,
  findLatestNsclcPredictionRunForCreatedPatient,
};
