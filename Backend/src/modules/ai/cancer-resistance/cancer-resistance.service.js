// Implements cancer resistance AI gateway workflows.
const { buildSender, sendToRasa } = require("../ai.gateway");

// Executes the "start cancer resistance" workflow for this module.
async function startCancerResistance(userId, data) {
  const sender = buildSender(userId, data.sessionId);
  return sendToRasa(sender, data.entryIntent || "/start_cancer_resistance");
}

// Executes the "send cancer resistance message" workflow for this module.
async function sendCancerResistanceMessage(userId, data) {
  const sender = buildSender(userId, data.sessionId);
  return sendToRasa(sender, data.message);
}

module.exports = {
  startCancerResistance,
  sendCancerResistanceMessage,
};
