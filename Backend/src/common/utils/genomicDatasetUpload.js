// Centralizes genomic dataset (CSV) upload storage, validation, and cleanup helpers.
const fs = require("fs");
const path = require("path");
const multer = require("multer");
const { AppError } = require("../errors/AppError");

const allowedGenomicDatasetMimeTypes = new Set([
  "text/csv",
  "text/plain",
  "application/csv",
  "application/vnd.ms-excel",
  "application/octet-stream",
]);

const allowedGenomicDatasetExtensions = new Set([".csv", ".tsv", ".txt"]);

const genomicDatasetFieldNames = ["mutationsFile", "expressionFile"];

const maxGenomicDatasetSize = Number.parseInt(
  process.env.AI_GENOMIC_MAX_UPLOAD_BYTES || String(100 * 1024 * 1024),
  10,
);

// Builds the upload directory path used for temporary genomic dataset storage.
function getGenomicDatasetUploadDir() {
  return path.join(__dirname, "../../uploads/genomic-datasets");
}

const genomicDatasetStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = getGenomicDatasetUploadDir();
    fs.mkdirSync(uploadDir, { recursive: true });
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    cb(null, `${uniqueSuffix}${path.extname(file.originalname)}`);
  },
});

const genomicDatasetUpload = multer({
  storage: genomicDatasetStorage,
  limits: {
    fileSize: maxGenomicDatasetSize,
    files: genomicDatasetFieldNames.length,
    fields: 10,
  },
});

const genomicDatasetUploadFields = genomicDatasetUpload.fields(
  genomicDatasetFieldNames.map((name) => ({ name, maxCount: 1 })),
);

// Returns the uploaded genomic dataset files keyed by their logical input name.
function getUploadedGenomicDatasets(req) {
  if (!req.files || typeof req.files !== "object") {
    return { mutationsFile: null, expressionFile: null };
  }

  return {
    mutationsFile: req.files.mutationsFile?.[0] || null,
    expressionFile: req.files.expressionFile?.[0] || null,
  };
}

// Deletes uploaded genomic dataset files once they have been forwarded or rejected.
function removeUploadedGenomicDatasets(files) {
  for (const file of files) {
    const filePath = typeof file === "string" ? file : file?.path || null;
    if (!filePath) continue;

    try {
      fs.unlinkSync(filePath);
    } catch {
      // Ignore cleanup failures for already-removed files.
    }
  }
}

// Validates one uploaded genomic dataset file type and size.
function validateGenomicDatasetFile(file, label) {
  if (!file) return;

  const mimeType = String(file.mimetype || "").toLowerCase();
  const extension = path.extname(file.originalname || "").toLowerCase();
  const isAllowedMimeType = allowedGenomicDatasetMimeTypes.has(mimeType);
  const isAllowedExtension = allowedGenomicDatasetExtensions.has(extension);

  if (!isAllowedExtension || !isAllowedMimeType) {
    throw new AppError(
      `The ${label} file must be a CSV file`,
      400,
      "INVALID_FILE_TYPE",
    );
  }

  if (file.size > maxGenomicDatasetSize) {
    throw new AppError(
      `The ${label} file exceeds the ${Math.floor(
        maxGenomicDatasetSize / (1024 * 1024),
      )}MB limit`,
      400,
      "FILE_TOO_LARGE",
    );
  }
}

module.exports = {
  genomicDatasetFieldNames,
  genomicDatasetUploadFields,
  getUploadedGenomicDatasets,
  removeUploadedGenomicDatasets,
  validateGenomicDatasetFile,
};
