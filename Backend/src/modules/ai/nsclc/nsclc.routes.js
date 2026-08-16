// Declares NSCLC AI prediction routes.
const router = require("express").Router();
const controller = require("./nsclc.controller");
const { requireAuth } = require("../../../middlewares/auth.middleware");
const { requireRole } = require("../../../middlewares/rbac.middleware");

router.use(requireAuth, requireRole("DOCTOR"));

router.post("/predict", controller.predictNsclc);
router.get("/last-result/:patientId", controller.getLastNsclcResult);

module.exports = router;
