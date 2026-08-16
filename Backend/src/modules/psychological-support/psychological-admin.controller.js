// Maps psychological knowledge article admin requests to the service layer.
const { asyncHandler } = require("../../common/utils/asyncHandler");
const service = require("./psychological-support.service");
const {
  listArticlesQuerySchema,
  knowledgeArticleCreateSchema,
  knowledgeArticleUpdateSchema,
} = require("./psychological-support.validation");

// Handles admin knowledge article listing.
const listKnowledgeArticles = asyncHandler(async (req, res) => {
  const query = listArticlesQuerySchema.parse(req.query);
  const result = await service.listKnowledgeArticlesForAdmin(query);
  res.json(result);
});

// Handles admin knowledge article retrieval by id.
const getKnowledgeArticleById = asyncHandler(async (req, res) => {
  const result = await service.getKnowledgeArticleByIdForAdmin(req.params.id);
  res.json(result);
});

// Handles admin knowledge article metadata retrieval by id.
const getKnowledgeArticleMetadataById = asyncHandler(async (req, res) => {
  const result = await service.getKnowledgeArticleMetadataByIdForAdmin(req.params.id);
  res.json(result);
});

// Handles admin knowledge article creation.
const createKnowledgeArticle = asyncHandler(async (req, res) => {
  const data = knowledgeArticleCreateSchema.parse(req.body);
  const result = await service.createKnowledgeArticle(data);
  res.status(201).json(result);
});

// Handles admin knowledge article updates.
const updateKnowledgeArticle = asyncHandler(async (req, res) => {
  const data = knowledgeArticleUpdateSchema.parse(req.body);
  const result = await service.updateKnowledgeArticle(req.params.id, data);
  res.json(result);
});

// Handles admin knowledge article deletion.
const deleteKnowledgeArticle = asyncHandler(async (req, res) => {
  const result = await service.deleteKnowledgeArticle(req.params.id);
  res.json(result);
});

module.exports = {
  listKnowledgeArticles,
  createKnowledgeArticle,
  deleteKnowledgeArticle,
  getKnowledgeArticleById,
  getKnowledgeArticleMetadataById,
  updateKnowledgeArticle,
};
