// Generates and parses QR payloads used by doctor and patient linking flows.
const { randomUUID } = require("crypto");

// Builds a QR payload string for doctor or patient linking workflows.
function generateRoleQrCode(role, entityId = null) {
  const prefix = role === "DOCTOR" ? "doctor" : "patient";
  const token = randomUUID();

  if (entityId) {
    return `curevoo:${prefix}:${entityId}:${token}`;
  }

  return `curevoo:${prefix}:${token}`;
}

// Parses a QR payload string into role, entity id, and token parts.
function parseRoleQrCode(qrCode) {
  if (typeof qrCode !== "string") return null;

  const parts = qrCode.trim().split(":");
  if (parts.length < 3 || parts[0] !== "curevoo") return null;

  const role =
    parts[1] === "doctor"
      ? "DOCTOR"
      : parts[1] === "patient"
        ? "PATIENT"
        : null;

  if (!role) return null;

  if (parts.length >= 4) {
    return {
      role,
      entityId: parts[2],
      token: parts.slice(3).join(":"),
    };
  }

  return {
    role,
    entityId: null,
    token: parts.slice(2).join(":"),
  };
}

module.exports = { generateRoleQrCode, parseRoleQrCode };
