// Declares admin routes for psychological knowledge article management.
const router = require("express").Router();
const controller = require("./psychological-admin.controller");
const { requireAuth } = require("../../middlewares/auth.middleware");
const { requireRole } = require("../../middlewares/rbac.middleware");

router.use(requireAuth, requireRole("ADMIN"));

router.get("/", controller.listKnowledgeArticles);
router.get("/:id/metadata", controller.getKnowledgeArticleMetadataById);
router.get("/:id", controller.getKnowledgeArticleById);
router.post("/", controller.createKnowledgeArticle);
router.put("/:id", controller.updateKnowledgeArticle);
router.delete("/:id", controller.deleteKnowledgeArticle);

module.exports = router;
