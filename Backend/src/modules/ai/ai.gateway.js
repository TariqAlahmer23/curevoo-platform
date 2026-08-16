// Shares sender construction and Rasa proxy logic across AI feature modules.
const { AppError } = require("../../common/errors/AppError");

function getRasaBaseUrl() {
  return (
    process.env.AI_RASA_BASE_URL ||
    process.env.RASA_BASE_URL ||
    "http://localhost:5005"
  ).replace(/\/+$/, "");
}

// Builds the stable sender used when proxying to Rasa.
function buildSender(userId, sessionId) {
  return sessionId || `user-${userId}`;
}

// Sends a raw message payload to the Rasa REST webhook and returns the upstream array unchanged.
async function sendToRasa(sender, message) {
  let response;

  try {
    response = await fetch(`${getRasaBaseUrl()}/webhooks/rest/webhook`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ sender, message }),
    });
  } catch {
    throw new AppError(
      "AI service is unavailable",
      503,
      "AI_SERVICE_UNAVAILABLE",
    );
  }

  if (!response.ok) {
    throw new AppError("AI service request failed", 502, "AI_UPSTREAM_ERROR");
  }

  const payload = await response.json();
  if (!Array.isArray(payload)) {
    throw new AppError(
      "AI service returned an invalid response",
      502,
      "AI_INVALID_RESPONSE",
    );
  }

  if (!payload.length) {
    throw new AppError(
      "AI service returned an empty response",
      502,
      "AI_EMPTY_RESPONSE",
    );
  }

  return payload;
}

module.exports = {
  buildSender,
  sendToRasa,
};
