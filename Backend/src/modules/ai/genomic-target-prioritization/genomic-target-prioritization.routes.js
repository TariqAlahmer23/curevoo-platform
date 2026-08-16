// Declares genomic target prioritization AI routes.
const router = require("express").Router();
const controller = require("./genomic-target-prioritization.controller");
const { requireAuth } = require("../../../middlewares/auth.middleware");
const { requireRole } = require("../../../middlewares/rbac.middleware");
const {
  genomicDatasetUploadFields,
} = require("../../../common/utils/genomicDatasetUpload");

router.use(requireAuth, requireRole("DOCTOR"));

router.get("/health", controller.checkHealth);
router.post("/analyze", genomicDatasetUploadFields, controller.analyzeGenomicTargets);
router.get("/results/:runId", controller.getGenomicAnalysisResult);
router.get("/results/:runId/report", controller.getGenomicAnalysisReport);

module.exports = router;
