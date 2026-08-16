// Protects uploaded files by requiring either a valid bearer token or a signed URL.
const crypto = require("crypto");
const jwt = require("jsonwebtoken");
const { env } = require("../config/env");
const { AppError } = require("../common/errors/AppError");

function constantTimeEquals(a, b) {
  const left = Buffer.from(String(a || ""));
  const right = Buffer.from(String(b || ""));
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
}

function buildUploadSignature(pathname, expires) {
  const secret = process.env.UPLOAD_SIGNING_SECRET || env.jwt.accessSecret;
  return crypto
    .createHmac("sha256", secret)
    .update(`${pathname}:${expires}`)
    .digest("hex");
}

function hasValidBearerToken(req) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) return false;

  try {
    jwt.verify(token, env.jwt.accessSecret);
    return true;
  } catch {
    return false;
  }
}

function hasValidSignedUrl(req) {
  const expires = Number(req.query.expires);
  const signature = String(req.query.signature || "");
  if (!Number.isFinite(expires) || !signature) return false;
  if (expires * 1000 <= Date.now()) return false;

  const expected = buildUploadSignature(req.path, String(expires));
  return constantTimeEquals(signature, expected);
}

function protectUploads(req, res, next) {
  if (hasValidBearerToken(req) || hasValidSignedUrl(req)) return next();
  return next(new AppError("Unauthorized upload access", 401, "UPLOAD_UNAUTHORIZED"));
}

module.exports = {
  protectUploads,
  buildUploadSignature,
};
