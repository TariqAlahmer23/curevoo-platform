// Maps cancer resistance AI requests to the service layer.
const { asyncHandler } = require("../../../common/utils/asyncHandler");
const service = require("./cancer-resistance.service");
const {
  startCancerResistanceSchema,
  sendCancerResistanceMessageSchema,
} = require("./cancer-resistance.validation");

// Handles the "start cancer resistance" endpoint and returns the upstream Rasa array unchanged.
const startCancerResistance = asyncHandler(async (req, res) => {
  const data = startCancerResistanceSchema.parse(req.body);
  const result = await service.startCancerResistance(req.user.sub, data);
  res.json(result);
});

// Handles the "send cancer resistance message" endpoint and returns the upstream Rasa array unchanged.
const sendCancerResistanceMessage = asyncHandler(async (req, res) => {
  const data = sendCancerResistanceMessageSchema.parse(req.body);
  const result = await service.sendCancerResistanceMessage(req.user.sub, data);
  res.json(result);
});

module.exports = {
  startCancerResistance,
  sendCancerResistanceMessage,
};
