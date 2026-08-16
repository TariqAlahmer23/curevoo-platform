// Normalizes runtime, validation, and upload errors into a consistent API response.
const { AppError } = require("../common/errors/AppError");
const { ZodError } = require("zod");
const multer = require("multer");
const {
  doctorPhotoFieldNames,
  getUploadedDoctorPhoto,
  removeUploadedFile,
} = require("../common/utils/doctorPhoto");
const {
  medicalRecordImageFieldNames,
  getUploadedMedicalRecordImages,
  removeUploadedMedicalRecordImages,
} = require("../common/utils/medicalRecordImages");

// Converts application, validation, and upload errors into a consistent API response.
function errorMiddleware(err, req, res, next) {
  if (err instanceof multer.MulterError) {
    const uploadedPhoto = getUploadedDoctorPhoto(req);
    if (uploadedPhoto) removeUploadedFile(uploadedPhoto);

    const uploadedMedicalRecordImages = getUploadedMedicalRecordImages(req);
    if (uploadedMedicalRecordImages.length) {
      removeUploadedMedicalRecordImages(uploadedMedicalRecordImages);
    }
  }

  const e = err instanceof AppError
    ? err
    : err instanceof multer.MulterError
      ? new AppError(
          err.code === "LIMIT_FILE_SIZE"
            ? "Uploaded file exceeds the allowed size limit"
            : err.code === "LIMIT_UNEXPECTED_FILE"
              ? `Use one of these file field names: ${[
                  ...doctorPhotoFieldNames,
                  ...medicalRecordImageFieldNames,
                ].join(", ")}`
              : "Upload failed",
          400,
          err.code === "LIMIT_FILE_SIZE"
            ? "FILE_TOO_LARGE"
            : err.code === "LIMIT_UNEXPECTED_FILE"
              ? "UNEXPECTED_FILE_FIELD"
              : "UPLOAD_FAILED",
        )
    : err instanceof ZodError
      ? new AppError("Validation failed", 400, "VALIDATION_ERROR")
      : new AppError("Internal Server Error", 500, "INTERNAL_ERROR");

  if (!(err instanceof AppError) && !(err instanceof ZodError)) console.error(err);

  const details =
    err instanceof ZodError
      ? err.issues.map((issue) => ({
          path: issue.path.join("."),
          message: issue.message,
        }))
      : undefined;

  res.status(e.statusCode).json({
    ok: false,
    error: { code: e.code, message: e.message, details },
  });
}

module.exports = { errorMiddleware };
