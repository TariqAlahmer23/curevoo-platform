// Declares patient psychological support routes.
const router = require("express").Router();
const controller = require("./psychological-support.controller");
const { requireAuth } = require("../../middlewares/auth.middleware");
const { requireRole } = require("../../middlewares/rbac.middleware");

router.use(requireAuth, requireRole("PATIENT"));

router.post("/grace-link", controller.createGraceLink);
router.post("/chat", controller.sendChatMessage);
router.get("/chat/session", controller.getChatSession);
router.post("/exercises/complete", controller.completeExercise);
router.get("/articles", controller.listArticles);
router.get("/articles/:id", controller.getArticleById);
router.post("/search", controller.searchEducation);

module.exports = router;
