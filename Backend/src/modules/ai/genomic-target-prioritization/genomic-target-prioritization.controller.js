// Maps genomic target prioritization requests to the service layer.
const { asyncHandler } = require("../../../common/utils/asyncHandler");
const {
  getUploadedGenomicDatasets,
  removeUploadedGenomicDatasets,
  validateGenomicDatasetFile,
} = require("../../../common/utils/genomicDatasetUpload");
const service = require("./genomic-target-prioritization.service");
const {
  analyzeGenomicTargetsSchema,
  genomicAnalysisRunIdParamSchema,
} = require("./genomic-target-prioritization.validation");

// Handles AI service health checks for the genomic target prioritization workflow.
const checkHealth = asyncHandler(async (req, res) => {
  const result = await service.checkHealth();
  res.json(result);
});

// Handles genomic target prioritization runs and returns the ranked research report.
const analyzeGenomicTargets = asyncHandler(async (req, res) => {
  const { mutationsFile, expressionFile } = getUploadedGenomicDatasets(req);
  const uploadedFiles = [mutationsFile, expressionFile].filter(Boolean);

  try {
    const { topN } = analyzeGenomicTargetsSchema.parse(req.body);
    validateGenomicDatasetFile(mutationsFile, "mutation");
    validateGenomicDatasetFile(expressionFile, "RNA expression");

    const result = await service.analyze({ topN, mutationsFile, expressionFile });
    res.json(result);
  } finally {
    removeUploadedGenomicDatasets(uploadedFiles);
  }
});

// Handles "get a stored genomic target prioritization result" requests.
const getGenomicAnalysisResult = asyncHandler(async (req, res) => {
  const { runId } = genomicAnalysisRunIdParamSchema.parse(req.params);
  const result = await service.getResult(runId);
  res.json(result);
});

// Handles "download the generated research report" requests for one run.
const getGenomicAnalysisReport = asyncHandler(async (req, res) => {
  const { runId } = genomicAnalysisRunIdParamSchema.parse(req.params);
  const markdown = await service.getResultReport(runId);

  res.type("text/markdown; charset=utf-8");
  res.setHeader(
    "Content-Disposition",
    `inline; filename="genomic-target-prioritization-${runId}.md"`,
  );
  res.send(markdown);
});

module.exports = {
  checkHealth,
  analyzeGenomicTargets,
  getGenomicAnalysisResult,
  getGenomicAnalysisReport,
};
