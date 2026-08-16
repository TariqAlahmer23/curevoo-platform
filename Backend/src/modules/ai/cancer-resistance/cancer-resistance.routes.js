// Declares cancer resistance AI routes.
const router = require("express").Router();
const controller = require("./cancer-resistance.controller");
const { requireAuth } = require("../../../middlewares/auth.middleware");
const { requireRole } = require("../../../middlewares/rbac.middleware");
const nsclcController = require("../nsclc/nsclc.controller");

router.use(requireAuth);

router.post("/start", requireRole("PATIENT"), controller.startCancerResistance);
router.post("/message", requireRole("PATIENT"), controller.sendCancerResistanceMessage);
router.post("/predict", requireRole("DOCTOR"), nsclcController.predictNsclc);
router.get("/last-result/:patientId", requireRole("DOCTOR"), nsclcController.getLastNsclcResult);

module.exports = router;
