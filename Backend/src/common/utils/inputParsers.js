// Normalizes loosely formatted request values before schema validation.
function normalizeOptionalString(value) {
  if (value === undefined || value === null) return undefined;
  if (typeof value !== "string") return value;

  const trimmed = value.trim();
  return trimmed === "" ? undefined : trimmed;
}

// Parses optional integer input while preserving undefined for empty values.
function parseOptionalInteger(value) {
  if (value === undefined || value === null || value === "") return undefined;
  if (typeof value === "number") return Number.isFinite(value) ? value : value;
  if (typeof value !== "string") return value;

  const trimmed = value.trim();
  if (trimmed === "") return undefined;

  const parsed = Number(trimmed);
  return Number.isInteger(parsed) ? parsed : value;
}

// Parses an optional JSON object from native objects or JSON strings.
function parseOptionalJsonObject(value) {
  if (value === undefined || value === null || value === "") return undefined;
  if (typeof value !== "string") return value;

  const trimmed = value.trim();
  if (!trimmed) return undefined;

  try {
    return JSON.parse(trimmed);
  } catch {
    return value;
  }
}

// Parses optional JSON values from native values or JSON strings.
function parseOptionalJsonValue(value) {
  if (value === undefined || value === null || value === "") return undefined;
  if (typeof value !== "string") return value;

  const trimmed = value.trim();
  if (!trimmed) return undefined;

  try {
    return JSON.parse(trimmed);
  } catch {
    return value;
  }
}

// Parses string list input from arrays, JSON strings, or comma-separated values.
function parseStringArray(value) {
  if (value === undefined || value === null || value === "") return undefined;

  if (Array.isArray(value)) {
    return value
      .flatMap((item) => parseStringArray(item) || [])
      .filter((item) => typeof item === "string" && item.length > 0);
  }

  if (typeof value !== "string") return value;

  const trimmed = value.trim();
  if (!trimmed) return undefined;

  if (trimmed.startsWith("[")) {
    try {
      const parsed = JSON.parse(trimmed);
      if (Array.isArray(parsed)) {
        return parsed
          .map((item) =>
            typeof item === "string" ? item.trim() : String(item).trim(),
          )
          .filter(Boolean);
      }
    } catch {
      // Fall back to comma-separated parsing.
    }
  }

  return trimmed
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

module.exports = {
  normalizeOptionalString,
  parseOptionalInteger,
  parseOptionalJsonObject,
  parseOptionalJsonValue,
  parseStringArray,
};
