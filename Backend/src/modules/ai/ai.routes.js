// Declares AI gateway routes.
const router = require("express").Router();
const cancerDiagnosisRoutes = require("./cancer-diagnosis/cancer-diagnosis.routes");
const cancerResistanceRoutes = require("./cancer-resistance/cancer-resistance.routes");
const genomicTargetPrioritizationRoutes = require("./genomic-target-prioritization/genomic-target-prioritization.routes");
const nsclcRoutes = require("./nsclc/nsclc.routes");

router.use("/cancer-diagnosis", cancerDiagnosisRoutes);
router.use("/cancer-resistance", cancerResistanceRoutes);
router.use("/genomic-target-prioritization", genomicTargetPrioritizationRoutes);
router.use("/nsclc", nsclcRoutes);

module.exports = router;
