// Maps admin doctor/patient management requests to the service layer.
const { asyncHandler } = require("../../common/utils/asyncHandler");
const { AppError } = require("../../common/errors/AppError");
const service = require("./admin-users.service");
const {
  requiredDoctorCreateSchema,
  requiredPatientCreateSchema,
  updateDoctorByAdminSchema,
  updatePatientByAdminSchema,
} = require("./admin-users.validation");
const {
  buildDoctorPhotoUrl,
  getUploadedDoctorPhoto,
  removeUploadedFile,
  validateDoctorPhotoFile,
} = require("../../common/utils/doctorPhoto");

// Handles listing all doctors for admin.
const listDoctors = asyncHandler(async (req, res) => {
  const result = await service.listDoctorsByAdmin();
  res.json({ ok: true, data: result });
});

// Handles listing all patients for admin.
const listPatients = asyncHandler(async (req, res) => {
  const result = await service.listPatientsByAdmin();
  res.json({ ok: true, data: result });
});

// Handles admin doctor creation.
const createDoctor = asyncHandler(async (req, res) => {
  const photoFile = getUploadedDoctorPhoto(req);

  try {
    if (photoFile) validateDoctorPhotoFile(photoFile);

    const data = requiredDoctorCreateSchema.parse({
      ...req.body,
      role: "DOCTOR",
    });

    const result = await service.createDoctorByAdmin(
      {
        ...data,
        photoUrl: photoFile ? buildDoctorPhotoUrl(photoFile) : undefined,
      },
      {
        id: req.user.sub,
        role: req.user.role,
      },
    );

    res.status(201).json({ ok: true, data: result });
  } catch (error) {
    if (photoFile) removeUploadedFile(photoFile);
    throw error;
  }
});

// Handles admin patient creation.
const createPatient = asyncHandler(async (req, res) => {
  const photoFile = getUploadedDoctorPhoto(req);

  try {
    const data = requiredPatientCreateSchema.parse({
      ...req.body,
      role: "PATIENT",
    });

    if (photoFile) {
      throw new AppError(
        "Photo upload is available only for doctor registration",
        400,
        "PHOTO_DOCTOR_ONLY",
      );
    }

    const result = await service.createPatientByAdmin(data, {
      id: req.user.sub,
      role: req.user.role,
    });

    res.status(201).json({ ok: true, data: result });
  } catch (error) {
    if (photoFile) removeUploadedFile(photoFile);
    throw error;
  }
});

// Handles admin doctor updates.
const updateDoctor = asyncHandler(async (req, res) => {
  const data = updateDoctorByAdminSchema.parse(req.body);
  const result = await service.updateDoctorByAdmin(req.params.userId, data);
  res.json({ ok: true, data: result });
});

// Handles admin patient updates.
const updatePatient = asyncHandler(async (req, res) => {
  const data = updatePatientByAdminSchema.parse(req.body);
  const result = await service.updatePatientByAdmin(req.params.userId, data);
  res.json({ ok: true, data: result });
});

// Handles admin doctor deletion.
const deleteDoctor = asyncHandler(async (req, res) => {
  const result = await service.deleteDoctorByAdmin(req.user.sub, req.params.userId);
  res.json({ ok: true, data: result });
});

// Handles admin patient deletion.
const deletePatient = asyncHandler(async (req, res) => {
  const result = await service.deletePatientByAdmin(req.user.sub, req.params.userId);
  res.json({ ok: true, data: result });
});

module.exports = {
  listDoctors,
  listPatients,
  createDoctor,
  createPatient,
  updateDoctor,
  updatePatient,
  deleteDoctor,
  deletePatient,
};
