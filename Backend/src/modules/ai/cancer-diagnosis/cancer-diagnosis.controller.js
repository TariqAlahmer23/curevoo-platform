// Maps cancer diagnosis AI requests to the service layer.
const { asyncHandler } = require("../../../common/utils/asyncHandler");
const {
  getUploadedAiDiagnosisImage,
  removeUploadedAiDiagnosisImage,
  validateAiDiagnosisImageFile,
} = require("../../../common/utils/aiDiagnosisImage");
const service = require("./cancer-diagnosis.service");
const {
  startCancerDiagnosisSchema,
  sendCancerDiagnosisMessageSchema,
  submitCancerDiagnosisImageSchema,
} = require("./cancer-diagnosis.validation");

// Handles the "start cancer diagnosis" endpoint and returns the upstream Rasa array unchanged.
const startCancerDiagnosis = asyncHandler(async (req, res) => {
  const data = startCancerDiagnosisSchema.parse(req.body);
  const result = await service.startCancerDiagnosis(req.user.sub, data);
  res.json(result);
});

// Handles the "send cancer diagnosis message" endpoint and returns the upstream Rasa array unchanged.
const sendCancerDiagnosisMessage = asyncHandler(async (req, res) => {
  const data = sendCancerDiagnosisMessageSchema.parse(req.body);
  const result = await service.sendCancerDiagnosisMessage(req.user.sub, data);
  res.json(result);
});

// Handles the "submit cancer diagnosis image" endpoint and returns the upstream Rasa array unchanged.
const submitCancerDiagnosisImage = asyncHandler(async (req, res) => {
  const uploadedImage = getUploadedAiDiagnosisImage(req);

  try {
    validateAiDiagnosisImageFile(uploadedImage);
    const data = submitCancerDiagnosisImageSchema.parse(req.body);
    const result = await service.submitCancerDiagnosisImage(req.user.sub, {
      ...data,
      imageRef: uploadedImage.path,
      imageMimeType: uploadedImage.mimetype,
    });

    res.json(result);
  } catch (error) {
    removeUploadedAiDiagnosisImage(uploadedImage);
    throw error;
  }
});

module.exports = {
  startCancerDiagnosis,
  sendCancerDiagnosisMessage,
  submitCancerDiagnosisImage,
};
