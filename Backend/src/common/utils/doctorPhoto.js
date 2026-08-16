// Centralizes doctor photo upload storage, validation, and cleanup helpers.
const fs = require("fs");
const path = require("path");
const multer = require("multer");
const { AppError } = require("../errors/AppError");

const allowedDoctorPhotoMimeTypes = new Set([
  "image/jpg",
  "image/jpeg",
  "image/png",
  "image/gif",
  "image/webp",
  "image/bmp",
  "image/heic",
  "image/heif",
]);

const allowedDoctorPhotoExtensions = new Set([
  ".jpg",
  ".jpeg",
  ".png",
  ".gif",
  ".webp",
  ".bmp",
  ".heic",
  ".heif",
]);

const doctorPhotoFieldNames = [
  "photo",
  "avatar",
  "image",
  "profilePhoto",
  "profileImage",
];

const maxDoctorPhotoSize = 5 * 1024 * 1024;

// Builds the upload directory path used for doctor photo storage.
function getDoctorPhotoUploadDir() {
  return path.join(__dirname, "../../uploads/doctors");
}

const doctorPhotoStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = getDoctorPhotoUploadDir();
    fs.mkdirSync(uploadDir, { recursive: true });
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    cb(null, `${uniqueSuffix}${path.extname(file.originalname)}`);
  },
});

const doctorPhotoUpload = multer({
  storage: doctorPhotoStorage,
  limits: {
    fileSize: maxDoctorPhotoSize,
    files: 1,
    fields: 20,
  },
});

const doctorPhotoUploadFields = doctorPhotoUpload.fields(
  doctorPhotoFieldNames.map((name) => ({ name, maxCount: 1 })),
);

// Returns the uploaded doctor photo regardless of which supported field name was used.
function getUploadedDoctorPhoto(req) {
  if (req.file) return req.file;
  if (!req.files || typeof req.files !== "object") return null;

  for (const fieldName of doctorPhotoFieldNames) {
    const file = req.files[fieldName]?.[0];
    if (file) return file;
  }

  return null;
}

// Deletes an uploaded file when validation fails or cleanup is required.
function removeUploadedFile(fileOrPath) {
  const filePath =
    typeof fileOrPath === "string" ? fileOrPath : fileOrPath?.path || null;

  if (!filePath) return;

  try {
    fs.unlinkSync(filePath);
  } catch {
    // Ignore cleanup failures for already-removed files.
  }
}

// Validates uploaded doctor photo type and file size limits.
function validateDoctorPhotoFile(file) {
  if (!file) return;

  const mimeType = String(file.mimetype || "").toLowerCase();
  const extension = path.extname(file.originalname || "").toLowerCase();
  const isAllowedMimeType = allowedDoctorPhotoMimeTypes.has(mimeType);
  const isAllowedExtension = allowedDoctorPhotoExtensions.has(extension);

  if (!isAllowedMimeType && !isAllowedExtension) {
    throw new AppError(
      "Only image files are allowed",
      400,
      "INVALID_FILE_TYPE",
    );
  }

  if (file.size > maxDoctorPhotoSize) {
    throw new AppError(
      "File size must be less than 5MB",
      400,
      "FILE_TOO_LARGE",
    );
  }
}

// Builds the public URL returned for an uploaded doctor photo.
function buildDoctorPhotoUrl(file) {
  return `/uploads/doctors/${file.filename}`;
}

module.exports = {
  doctorPhotoUpload,
  doctorPhotoUploadFields,
  doctorPhotoFieldNames,
  getUploadedDoctorPhoto,
  removeUploadedFile,
  validateDoctorPhotoFile,
  buildDoctorPhotoUrl,
  maxDoctorPhotoSize,
};
