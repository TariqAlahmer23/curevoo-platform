// Implements doctor profile, settings, photo, and QR workflows.
const { AppError } = require("../../common/errors/AppError");
const {
  getDoctorProfileByUserId,
  updateDoctorProfile,
  getDoctorSettingsByUserId,
  updateDoctorSettings,
  updateDoctorPhotoUrl,
  updateDoctorQrCode,
  listDoctorLinkedPatients,
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
} = require("./doctor.repo");
const { generateRoleQrCode } = require("../../common/utils/qrCode");
const patientsService = require("../patients/patients.service");

function toTrimmedStringOrNull(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed || null;
}

function extractDiagnosis(record) {
  if (!record || typeof record !== "object" || Array.isArray(record)) {
    return null;
  }

  return (
    toTrimmedStringOrNull(record.diagnosis) ||
    toTrimmedStringOrNull(record.lastDiagnosis)
  );
}

function resolveLastDiagnosis(historyRecord, treatmentHistory) {
  return (
    extractDiagnosis(historyRecord?.record) ||
    extractDiagnosis(treatmentHistory?.[0]?.record) ||
    toTrimmedStringOrNull(treatmentHistory?.[0]?.curevooDetectorResult)
  );
}

function formatLinkedPatientSummary(link) {
  const patient = link?.patient;

  return {
    id: patient?.id || null,
    patientType: "NORMAL",
    name: patient?.patientProfile?.fullName || patient?.name || null,
    sex: patient?.patientProfile?.sex || null,
    age: patient?.patientProfile?.age ?? patient?.age ?? null,
    phoneNumber: patient?.phoneNumber || null,
    number: patient?.phoneNumber || null,
  };
}

function formatCreatedPatientSummary(patient) {
  return {
    id: patient.id,
    patientType: "CREATED",
    name: patient.fullName || null,
    sex: patient.sex || null,
    age: patient.age ?? null,
    phoneNumber: patient.phoneNumber || null,
    number: patient.phoneNumber || null,
  };
}

function formatLinkedPatientDetails(patient) {
  const profile = patient?.patientProfile;
  const fullName = profile?.fullName || patient?.name || null;

  return {
    id: patient?.id || null,
    sourcePatientUserId: patient?.id || null,
    name: fullName,
    fullName,
    email: patient?.email || null,
    phoneNumber: patient?.phoneNumber || null,
    age: profile?.age ?? patient?.age ?? null,
    sex: profile?.sex || null,
    address: profile?.address || null,
    medicalHistory: profile?.medicalHistory || null,
    riskFactors: profile?.riskFactors ?? null,
    createdAt: profile?.createdAt || patient?.createdAt || null,
    updatedAt: profile?.updatedAt || patient?.updatedAt || null,
  };
}

function formatCreatedPatientDetails(patient) {
  return {
    id: patient?.id || null,
    sourcePatientUserId: patient?.sourcePatientUserId || null,
    name: patient?.fullName || null,
    fullName: patient?.fullName || null,
    email: null,
    phoneNumber: patient?.phoneNumber || null,
    age: patient?.age ?? null,
    sex: patient?.sex || null,
    address: null,
    medicalHistory: patient?.medicalHistory || null,
    riskFactors: patient?.riskFactors ?? null,
    createdAt: patient?.createdAt || null,
    updatedAt: patient?.createdAt || null,
  };
}

function buildCreatedPatientHistoryRecord(patient) {
  if (!patient?.medicalHistory) return null;

  return {
    id: patient.id,
    patientId: patient.id,
    record: {
      summary: patient.medicalHistory,
    },
    createdAt: patient.createdAt,
    updatedAt: patient.createdAt,
  };
}

async function resolveDoctorPatient(doctorUserId, patientId) {
  const linkedPatient = await findDoctorLinkedPatientById(
    doctorUserId,
    patientId,
  );
  if (linkedPatient?.patient) {
    return {
      patientType: "NORMAL",
      patientId: linkedPatient.patient.id,
      patient: linkedPatient.patient,
    };
  }

  const createdPatient = await findDoctorCreatedPatientById(
    doctorUserId,
    patientId,
  );
  if (createdPatient) {
    return {
      patientType: "CREATED",
      patientId: createdPatient.id,
      patient: createdPatient,
    };
  }

  throw new AppError("Patient not found", 404, "PATIENT_NOT_FOUND");
}

// Shapes doctor profile data before returning it to doctor clients.
function formatDoctorProfile(profile) {
  if (!profile) return profile;

  return {
    id: profile.id,
    userId: profile.userId,
    email: profile.user?.email || null,
    name: profile.fullName || profile.user?.name || null,
    fullName: profile.fullName || profile.user?.name || null,
    phoneNumber: profile.user?.phoneNumber || null,
    age: profile.user?.age ?? null,
    specialization: profile.specialization,
    workingAt: profile.workingAt,
    languages: Array.isArray(profile.languages) ? profile.languages : [],
    location: profile.location,
    qualifications: profile.qualifications,
    experience: profile.experience,
    bio: profile.bio,
    photoUrl: profile.photoUrl,
    qrCode: profile.qrCode,
    consultationFee: profile.consultationFee,
    isActive: profile.isActive,
    createdAt: profile.createdAt,
    updatedAt: profile.updatedAt,
  };
}

// Executes the "get profile" business workflow for this module.
async function getProfile(userId) {
  const profile = await getDoctorProfileByUserId(userId);
  if (!profile) {
    throw new AppError("Doctor profile not found", 404, "PROFILE_NOT_FOUND");
  }
  return formatDoctorProfile(profile);
}

// Executes the "update profile" business workflow for this module.
async function updateProfile(userId, data) {
  const profile = await getDoctorProfileByUserId(userId);
  if (!profile) {
    throw new AppError("Doctor profile not found", 404, "PROFILE_NOT_FOUND");
  }
  const updated = await updateDoctorProfile(userId, data);
  return formatDoctorProfile(updated);
}

// Executes the "get settings" business workflow for this module.
async function getSettings(userId) {
  const settings = await getDoctorSettingsByUserId(userId);
  if (!settings) {
    throw new AppError("Doctor settings not found", 404, "SETTINGS_NOT_FOUND");
  }
  return settings;
}

// Executes the "update settings" business workflow for this module.
async function updateSettings(userId, data) {
  const settings = await getDoctorSettingsByUserId(userId);
  if (!settings) {
    throw new AppError("Doctor settings not found", 404, "SETTINGS_NOT_FOUND");
  }
  return updateDoctorSettings(userId, data);
}

// Executes the "upload photo" business workflow for this module.
async function uploadPhoto(userId, photoUrl) {
  const profile = await getDoctorProfileByUserId(userId);
  if (!profile) {
    throw new AppError("Doctor profile not found", 404, "PROFILE_NOT_FOUND");
  }
  return updateDoctorPhotoUrl(userId, photoUrl);
}

// Executes the "regenerate qr code" business workflow for this module.
async function regenerateQrCode(userId) {
  const profile = await getDoctorProfileByUserId(userId);
  if (!profile) {
    throw new AppError("Doctor profile not found", 404, "PROFILE_NOT_FOUND");
  }

  for (let attempt = 0; attempt < 5; attempt += 1) {
    const qrCode = generateRoleQrCode("DOCTOR", userId);
    try {
      const updated = await updateDoctorQrCode(userId, qrCode);
      return {
        doctorUserId: userId,
        qrCode: updated.qrCode,
        qrString: updated.qrCode,
      };
    } catch (error) {
      if (error?.code === "P2002") continue;
      throw error;
    }
  }

  throw new AppError(
    "Unable to regenerate QR code right now",
    500,
    "QR_REGENERATE_FAILED",
  );
}

// Executes the "list doctor patients" business workflow for this module.
async function listPatients(userId) {
  const [linkedPatients, createdPatients] = await Promise.all([
    listDoctorLinkedPatients(userId),
    patientsService.listDoctorCreatedPatients(userId),
  ]);

  return [
    ...linkedPatients.map(formatLinkedPatientSummary),
    ...createdPatients.map(formatCreatedPatientSummary),
  ];
}

// Executes the "create patient as doctor" business workflow for this module.
async function createPatient(userId, data) {
  return patientsService.createCreatedPatientByDoctor(userId, data);
}

// Executes the "get doctor patient by id" business workflow for this module.
async function getPatientById(doctorUserId, patientId) {
  const patient = await resolveDoctorPatient(doctorUserId, patientId);

  if (patient.patientType === "CREATED") {
    const [historyRecord, treatmentPlans] = await Promise.all([
      getLatestMedicalHistoryForSubject({ createdPatientId: patient.patient.id }),
      listTreatmentPlansForDoctorSubject(doctorUserId, {
        createdPatientId: patient.patient.id,
      }),
    ]);

    const currentTreatmentPlan =
      [...treatmentPlans].sort(
        (left, right) => new Date(right.updatedAt) - new Date(left.updatedAt),
      )[0] || null;

    return {
      patientType: patient.patientType,
      patientId: patient.patient.id,
      patient: formatCreatedPatientDetails(patient.patient),
      currentTreatmentPlan,
      lastDiagnosis: resolveLastDiagnosis(
        historyRecord || buildCreatedPatientHistoryRecord(patient.patient),
        [],
      ),
      treatmentHistory: [],
      historyRecord: historyRecord || buildCreatedPatientHistoryRecord(patient.patient),
    };
  }

  const [treatmentPlans, treatmentHistory, historyRecord] = await Promise.all([
    listTreatmentPlansForDoctorPatient(doctorUserId, patient.patientId),
    listMedicalRecordsForPatient(patient.patientId),
    getLatestMedicalHistoryForPatient(patient.patientId),
  ]);

  const currentTreatmentPlan =
    [...treatmentPlans].sort(
      (left, right) => new Date(right.updatedAt) - new Date(left.updatedAt),
    )[0] || null;

  return {
    patientType: patient.patientType,
    patientId: patient.patientId,
    patient: formatLinkedPatientDetails(patient.patient),
    currentTreatmentPlan,
    lastDiagnosis: resolveLastDiagnosis(historyRecord, treatmentHistory),
    treatmentHistory,
    historyRecord,
  };
}

// Executes the "update doctor-created patient" business workflow for this module.
async function updatePatient(doctorUserId, patientId, data) {
  const patient = await resolveDoctorPatient(doctorUserId, patientId);

  if (patient.patientType !== "CREATED" || patient.patient.sourcePatientUserId) {
    throw new AppError(
      "Only doctor-created patients can be updated from this endpoint",
      400,
      "PATIENT_UPDATE_NOT_ALLOWED",
    );
  }

  const updatedPatient = await updateDoctorCreatedPatientById(patient.patient.id, data);

  return {
    patientType: "CREATED",
    patientId: updatedPatient.id,
    patient: formatCreatedPatientDetails(updatedPatient),
  };
}

// Executes the "delete doctor-created patient" business workflow for this module.
async function deletePatient(doctorUserId, patientId) {
  const patient = await resolveDoctorPatient(doctorUserId, patientId);

  if (patient.patientType !== "CREATED" || patient.patient.sourcePatientUserId) {
    throw new AppError(
      "Only doctor-created patients can be deleted from this endpoint",
      400,
      "PATIENT_DELETE_NOT_ALLOWED",
    );
  }

  const deletedPatient = await deleteDoctorCreatedPatientById(patient.patient.id);

  return {
    deleted: true,
    patientType: "CREATED",
    patientId: deletedPatient.id,
  };
}

// Executes the "get doctor patient medical history" business workflow for this module.
async function getPatientMedicalHistory(doctorUserId, patientId) {
  return getPatientLatestMedicalHistory(doctorUserId, patientId);
}

// Executes the "get doctor patient latest medical history" business workflow.
async function getPatientLatestMedicalHistory(doctorUserId, patientId) {
  const patient = await resolveDoctorPatient(doctorUserId, patientId);

  if (patient.patientType === "CREATED") {
    const history = await getLatestMedicalHistoryForSubject({
      createdPatientId: patient.patient.id,
    });

    return {
      patientType: patient.patientType,
      patientId: patient.patient.id,
      data: history || {
        id: patient.patient.id,
        patientId: patient.patient.id,
        createdPatientId: patient.patient.id,
        record: patient.patient.medicalHistory
          ? { summary: patient.patient.medicalHistory }
          : null,
        createdAt: patient.patient.createdAt,
        updatedAt: patient.patient.createdAt,
      },
    };
  }

  const history = await getLatestMedicalHistoryForPatient(patient.patientId);
  return {
    patientType: patient.patientType,
    patientId: patient.patientId,
    data: history,
  };
}

// Executes the "list doctor patient medical histories" business workflow.
async function getPatientAllMedicalHistories(doctorUserId, patientId) {
  const patient = await resolveDoctorPatient(doctorUserId, patientId);

  if (patient.patientType === "CREATED") {
    const histories = await listMedicalHistoriesForSubject({
      createdPatientId: patient.patient.id,
    });
    const fallbackHistory = buildCreatedPatientHistoryRecord(patient.patient);

    return {
      patientType: patient.patientType,
      patientId: patient.patient.id,
      data: histories.length ? histories : fallbackHistory ? [fallbackHistory] : [],
    };
  }

  const histories = await listMedicalHistoriesForPatient(patient.patientId);
  return {
    patientType: patient.patientType,
    patientId: patient.patientId,
    data: histories,
  };
}

// Executes the "get doctor patient medical records" business workflow for this module.
async function getPatientMedicalRecords(doctorUserId, patientId) {
  return getPatientAllMedicalRecords(doctorUserId, patientId);
}

// Executes the "get doctor patient latest medical record" business workflow.
async function getPatientLatestMedicalRecord(doctorUserId, patientId) {
  const patient = await resolveDoctorPatient(doctorUserId, patientId);

  if (patient.patientType === "CREATED") {
    return {
      patientType: patient.patientType,
      patientId: patient.patient.id,
      data: null,
    };
  }

  const record = await getLatestMedicalRecordForPatient(patient.patientId);
  return {
    patientType: patient.patientType,
    patientId: patient.patientId,
    data: record,
  };
}

// Executes the "get doctor patient medical records" business workflow for this module.
async function getPatientAllMedicalRecords(doctorUserId, patientId) {
  const patient = await resolveDoctorPatient(doctorUserId, patientId);

  if (patient.patientType === "CREATED") {
    return {
      patientType: patient.patientType,
      patientId: patient.patient.id,
      data: [],
    };
  }

  const records = await listMedicalRecordsForPatient(patient.patientId);
  return {
    patientType: patient.patientType,
    patientId: patient.patientId,
    data: records,
  };
}

// Executes the "get doctor patient treatment plans" business workflow for this module.
async function getPatientTreatmentPlans(doctorUserId, patientId) {
  return getPatientAllTreatmentPlans(doctorUserId, patientId);
}

// Executes the "get doctor patient latest treatment plan" business workflow.
async function getPatientLatestTreatmentPlan(doctorUserId, patientId) {
  const patient = await resolveDoctorPatient(doctorUserId, patientId);

  if (patient.patientType === "CREATED") {
    const plan = await getLatestTreatmentPlanForDoctorSubject(doctorUserId, {
      createdPatientId: patient.patient.id,
    });

    return {
      patientType: patient.patientType,
      patientId: patient.patient.id,
      data: plan,
    };
  }

  const plan = await getLatestTreatmentPlanForDoctorPatient(
    doctorUserId,
    patient.patientId,
  );

  return {
    patientType: patient.patientType,
    patientId: patient.patientId,
    data: plan,
  };
}

// Executes the "get doctor patient treatment plans" business workflow for this module.
async function getPatientAllTreatmentPlans(doctorUserId, patientId) {
  const patient = await resolveDoctorPatient(doctorUserId, patientId);

  if (patient.patientType === "CREATED") {
    const plans = await listTreatmentPlansForDoctorSubject(doctorUserId, {
      createdPatientId: patient.patient.id,
    });

    return {
      patientType: patient.patientType,
      patientId: patient.patient.id,
      data: plans,
    };
  }

  const plans = await listTreatmentPlansForDoctorPatient(
    doctorUserId,
    patient.patientId,
  );

  return {
    patientType: patient.patientType,
    patientId: patient.patientId,
    data: plans,
  };
}

// Executes the "get doctor dashboard summary" business workflow for this module.
async function getDashboardSummary(doctorUserId) {
  return getDoctorDashboardSummary(doctorUserId);
}

module.exports = {
  getProfile,
  updateProfile,
  getSettings,
  updateSettings,
  uploadPhoto,
  regenerateQrCode,
  listPatients,
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
  getDashboardSummary,
};
