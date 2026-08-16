// Implements cancer diagnosis AI gateway workflows.
const { buildSender, sendToRasa } = require("../ai.gateway");

// Executes the "start cancer diagnosis" workflow for this module.
async function startCancerDiagnosis(userId, data) {
  const sender = buildSender(userId, data.sessionId);
  return sendToRasa(sender, data.entryIntent || "/start_questions_and_image");
}

// Executes the "send cancer diagnosis message" workflow for this module.
async function sendCancerDiagnosisMessage(userId, data) {
  const sender = buildSender(userId, data.sessionId);
  return sendToRasa(sender, data.message);
}

// Executes the "submit cancer diagnosis image" workflow for this module.
async function submitCancerDiagnosisImage(userId, data) {
  const sender = buildSender(userId, data.sessionId);
  return sendToRasa(
    sender,
    `/submit_image${JSON.stringify({
      image_ref: data.imageRef,
      image_mime_type: data.imageMimeType,
    })}`,
  );
}

module.exports = {
  startCancerDiagnosis,
  sendCancerDiagnosisMessage,
  submitCancerDiagnosisImage,
};
