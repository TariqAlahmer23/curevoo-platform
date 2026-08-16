// Centralizes medical-record image upload storage, validation, and formatting helpers.
const fs = require("fs");
const path = require("path");
const multer = require("multer");
const { AppError } = require("../errors/AppError");

const allowedMedicalRecordImageMimeTypes = new Set([
  "image/jpg",
  "image/jpeg",
  "image/png",
  "image/gif",
  "image/webp",
  "image/bmp",
  "image/tif",
  "image/tiff",
  "image/heic",
  "image/heif",
]);

const allowedMedicalRecordImageExtensions = new Set([
  ".jpg",
  ".jpeg",
  ".png",
  ".gif",
  ".webp",
  ".bmp",
  ".tif",
  ".tiff",
  ".heic",
  ".heif",
]);

const medicalRecordImageFieldNames = [
  "images",
  "image",
  "recordImages",
  "recordImage",
  "attachments",
  "files",
];

const maxMedicalRecordImageSize = 10 * 1024 * 1024;
const maxMedicalRecordImageCount = 10;

// Builds the upload directory path used for medical record image storage.
function getMedicalRecordImageUploadDir() {
  return path.join(__dirname, "../../uploads/medical-records");
}

const medicalRecordImageStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = getMedicalRecordImageUploadDir();
    fs.mkdirSync(uploadDir, { recursive: true });
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    cb(null, `${uniqueSuffix}${path.extname(file.originalname)}`);
  },
});

const medicalRecordImageUpload = multer({
  storage: medicalRecordImageStorage,
  limits: {
    fileSize: maxMedicalRecordImageSize,
    files: maxMedicalRecordImageCount,
    fields: 30,
  },
});

const medicalRecordImageUploadFields = medicalRecordImageUpload.fields(
  medicalRecordImageFieldNames.map((name) => ({
    name,
    maxCount: maxMedicalRecordImageCount,
  })),
);

// Returns all uploaded medical record images across supported field names.
function getUploadedMedicalRecordImages(req) {
  if (!req.files || typeof req.files !== "object") return [];

  return medicalRecordImageFieldNames.flatMap(
    (fieldName) => req.files[fieldName] || [],
  );
}

// Deletes uploaded files when validation fails or cleanup is required.
function removeUploadedMedicalRecordImages(files) {
  for (const file of files || []) {
    if (!file?.path) continue;

    try {
      fs.unlinkSync(file.path);
    } catch {
      // Ignore cleanup failures for already-removed files.
    }
  }
}

// Validates uploaded medical record image type and file size limits.
function validateMedicalRecordImageFiles(files) {
  for (const file of files || []) {
    const mimeType = String(file.mimetype || "").toLowerCase();
    const extension = path.extname(file.originalname || "").toLowerCase();
    const isAllowedMimeType = allowedMedicalRecordImageMimeTypes.has(mimeType);
    const isAllowedExtension = allowedMedicalRecordImageExtensions.has(extension);

    if (!isAllowedMimeType && !isAllowedExtension) {
      throw new AppError(
        "Only image files are allowed for medical records",
        400,
        "INVALID_FILE_TYPE",
      );
    }

    if (file.size > maxMedicalRecordImageSize) {
      throw new AppError(
        "Each medical record image must be less than 10MB",
        400,
        "FILE_TOO_LARGE",
      );
    }
  }
}

// Maps uploaded files to the JSON attachment objects stored inside a record.
function buildMedicalRecordImageEntries(files) {
  return (files || []).map((file) => ({
    url: `/uploads/medical-records/${file.filename}`,
    filename: file.filename,
    originalName: file.originalname,
    mimeType: file.mimetype,
    size: file.size,
    uploadedAt: new Date().toISOString(),
  }));
}

module.exports = {
  medicalRecordImageUpload,
  medicalRecordImageUploadFields,
  medicalRecordImageFieldNames,
  getUploadedMedicalRecordImages,
  removeUploadedMedicalRecordImages,
  validateMedicalRecordImageFiles,
  buildMedicalRecordImageEntries,
  maxMedicalRecordImageSize,
  maxMedicalRecordImageCount,
};
