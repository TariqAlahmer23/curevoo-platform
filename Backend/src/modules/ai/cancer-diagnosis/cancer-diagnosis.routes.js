// Declares cancer diagnosis AI routes.
const router = require("express").Router();
const controller = require("./cancer-diagnosis.controller");
const { requireAuth } = require("../../../middlewares/auth.middleware");
const {
  aiDiagnosisImageUploadFields,
} = require("../../../common/utils/aiDiagnosisImage");

router.use(requireAuth);

router.post("/start", controller.startCancerDiagnosis);
router.post("/message", controller.sendCancerDiagnosisMessage);
router.post("/image", aiDiagnosisImageUploadFields, controller.submitCancerDiagnosisImage);

module.exports = router;
