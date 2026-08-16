// Maps psychological support patient requests to the service layer.
const { asyncHandler } = require("../../common/utils/asyncHandler");
const service = require("./psychological-support.service");
const {
  chatMessageSchema,
  exerciseCompleteSchema,
  listArticlesQuerySchema,
  searchQuestionSchema,
} = require("./psychological-support.validation");

// Handles Grace deep-link generation for psychological support.
const createGraceLink = asyncHandler(async (req, res) => {
  const result = await service.createGraceRedirectLink(req.user.sub);
  res.json(result);
});

// Handles one patient chat message to Liora.
const sendChatMessage = asyncHandler(async (req, res) => {
  const data = chatMessageSchema.parse(req.body);
  const result = await service.sendPsychologicalChatMessage(req.user.sub, data);
  res.json(result);
});

// Handles retrieval of active patient chat session metadata.
const getChatSession = asyncHandler(async (req, res) => {
  const result = await service.getPsychologicalChatSession(req.user.sub);
  res.json(result);
});

// Handles psychological exercise completion logging.
const completeExercise = asyncHandler(async (req, res) => {
  const data = exerciseCompleteSchema.parse(req.body);
  const result = await service.completePsychologicalExercise(req.user.sub, data);
  res.json(result);
});

// Handles published article listing for patient psychological pages.
const listArticles = asyncHandler(async (req, res) => {
  const query = listArticlesQuerySchema.parse(req.query);
  const result = await service.listPsychologicalArticles(query);
  res.json(result);
});

// Handles one published article details lookup by id.
const getArticleById = asyncHandler(async (req, res) => {
  const result = await service.getPsychologicalArticleById(req.params.id);
  res.json(result);
});

// Handles educational cancer search with safety filtering.
const searchEducation = asyncHandler(async (req, res) => {
  const data = searchQuestionSchema.parse(req.body);
  const result = await service.searchEducationalCancerInfo(req.user.sub, data);
  res.json(result);
});

module.exports = {
  completeExercise,
  createGraceLink,
  getArticleById,
  getChatSession,
  listArticles,
  searchEducation,
  sendChatMessage,
};
