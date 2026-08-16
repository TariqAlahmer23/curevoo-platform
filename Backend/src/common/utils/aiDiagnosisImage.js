// Centralizes AI diagnosis image upload storage, validation, and cleanup helpers.
const fs = require("fs");
const path = require("path");
const multer = require("multer");
const { AppError } = require("../errors/AppError");

const allowedAiDiagnosisImageMimeTypes = new Set([
  "image/jpg",
  "image/jpeg",
  "image/png",
  "image/webp",
]);

const allowedAiDiagnosisImageExtensions = new Set([
  ".jpg",
  ".jpeg",
  ".png",
  ".webp",
]);

const aiDiagnosisImageFieldNames = [
  "image",
  "file",
  "upload",
];

const maxAiDiagnosisImageSize = 10 * 1024 * 1024;

// Builds the upload directory path used for AI diagnosis image storage.
function getAiDiagnosisImageUploadDir() {
  return path.join(__dirname, "../../uploads/ai-diagnosis");
}

const aiDiagnosisImageStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = getAiDiagnosisImageUploadDir();
    fs.mkdirSync(uploadDir, { recursive: true });
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    cb(null, `${uniqueSuffix}${path.extname(file.originalname)}`);
  },
});

const aiDiagnosisImageUpload = multer({
  storage: aiDiagnosisImageStorage,
  limits: {
    fileSize: maxAiDiagnosisImageSize,
    files: 1,
    fields: 20,
  },
});

const aiDiagnosisImageUploadFields = aiDiagnosisImageUpload.fields(
  aiDiagnosisImageFieldNames.map((name) => ({ name, maxCount: 1 })),
);

// Returns the uploaded AI diagnosis image regardless of which supported field name was used.
function getUploadedAiDiagnosisImage(req) {
  if (req.file) return req.file;
  if (!req.files || typeof req.files !== "object") return null;

  for (const fieldName of aiDiagnosisImageFieldNames) {
    const file = req.files[fieldName]?.[0];
    if (file) return file;
  }

  return null;
}

// Deletes an uploaded AI diagnosis image when validation fails or cleanup is required.
function removeUploadedAiDiagnosisImage(fileOrPath) {
  const filePath =
    typeof fileOrPath === "string" ? fileOrPath : fileOrPath?.path || null;

  if (!filePath) return;

  try {
    fs.unlinkSync(filePath);
  } catch {
    // Ignore cleanup failures for already-removed files.
  }
}

// Validates uploaded AI diagnosis image type and file size limits.
function validateAiDiagnosisImageFile(file) {
  if (!file) {
    throw new AppError("Image file is required", 400, "IMAGE_REQUIRED");
  }

  const mimeType = String(file.mimetype || "").toLowerCase();
  const extension = path.extname(file.originalname || "").toLowerCase();
  const isAllowedMimeType = allowedAiDiagnosisImageMimeTypes.has(mimeType);
  const isAllowedExtension = allowedAiDiagnosisImageExtensions.has(extension);

  if (!isAllowedMimeType && !isAllowedExtension) {
    throw new AppError(
      "Only JPG, JPEG, PNG, and WEBP images are allowed",
      400,
      "INVALID_FILE_TYPE",
    );
  }

  if (file.size > maxAiDiagnosisImageSize) {
    throw new AppError(
      "Image size must be less than 10MB",
      400,
      "FILE_TOO_LARGE",
    );
  }
}

module.exports = {
  aiDiagnosisImageUploadFields,
  aiDiagnosisImageFieldNames,
  getUploadedAiDiagnosisImage,
  removeUploadedAiDiagnosisImage,
  validateAiDiagnosisImageFile,
};
