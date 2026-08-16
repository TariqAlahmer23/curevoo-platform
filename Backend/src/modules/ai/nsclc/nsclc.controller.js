// Maps NSCLC AI prediction requests to the service layer.
const { asyncHandler } = require("../../../common/utils/asyncHandler");
const service = require("./nsclc.service");
const { predictNsclcSchema, nsclcPatientIdParamSchema } = require("./nsclc.validation");

// Handles NSCLC prediction requests and returns a frontend-friendly prediction object.
const predictNsclc = asyncHandler(async (req, res) => {
  const data = predictNsclcSchema.parse(req.body);
  const result = await service.predictNsclc(req.user.sub, data);
  res.json(result);
});

// Handles "get last NSCLC prediction result" requests for one doctor-accessible patient.
const getLastNsclcResult = asyncHandler(async (req, res) => {
  const { patientId } = nsclcPatientIdParamSchema.parse(req.params);
  const result = await service.getLastNsclcResult(req.user.sub, patientId);
  res.json(result);
});

module.exports = {
  predictNsclc,
  getLastNsclcResult,
};
