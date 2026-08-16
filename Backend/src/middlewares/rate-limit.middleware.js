// // Provides in-memory request throttling for brute-force and abuse mitigation.
// const { AppError } = require("../common/errors/AppError");

// const stores = new Map();

// function getStore(name) {
//   if (!stores.has(name)) stores.set(name, new Map());
//   return stores.get(name);
// }

// function cleanupExpiredEntries(store, now) {
//   for (const [key, value] of store.entries()) {
//     const resetAt = value?.resetAt || 0;
//     const blockedUntil = value?.blockedUntil || 0;
//     if (resetAt <= now && blockedUntil <= now) {
//       store.delete(key);
//     }
//   }
// }

// function createRateLimiter({
//   name,
//   windowMs,
//   max,
//   blockDurationMs,
//   keyGenerator,
//   message,
//   code,
// }) {
//   const resolvedName = name || "default";
//   const resolvedWindowMs = Number(windowMs || 60_000);
//   const resolvedMax = Number(max || 60);
//   const resolvedBlockDurationMs = Number(blockDurationMs || resolvedWindowMs);
//   const resolvedMessage = message || "Too many requests. Please try again later.";
//   const resolvedCode = code || "RATE_LIMITED";

//   return function rateLimiter(req, res, next) {
//     const now = Date.now();
//     const store = getStore(resolvedName);

//     if (store.size > 10_000) {
//       cleanupExpiredEntries(store, now);
//     }

//     const rawKey = keyGenerator ? keyGenerator(req) : req.ip;
//     const key = String(rawKey || req.ip || "unknown");

//     const existing = store.get(key);
//     if (existing?.blockedUntil && existing.blockedUntil > now) {
//       const retryAfterSeconds = Math.max(
//         1,
//         Math.ceil((existing.blockedUntil - now) / 1000),
//       );
//       res.set("Retry-After", String(retryAfterSeconds));
//       return next(new AppError(resolvedMessage, 429, resolvedCode));
//     }

//     if (!existing || existing.resetAt <= now) {
//       store.set(key, {
//         count: 1,
//         resetAt: now + resolvedWindowMs,
//         blockedUntil: 0,
//       });
//       return next();
//     }

//     existing.count += 1;

//     if (existing.count > resolvedMax) {
//       existing.blockedUntil = now + resolvedBlockDurationMs;
//       const retryAfterSeconds = Math.max(
//         1,
//         Math.ceil((existing.blockedUntil - now) / 1000),
//       );
//       res.set("Retry-After", String(retryAfterSeconds));
//       return next(new AppError(resolvedMessage, 429, resolvedCode));
//     }

//     store.set(key, existing);
//     return next();
//   };
// }

// function ipAndEmailKey(req) {
//   const email =
//     typeof req.body?.email === "string"
//       ? req.body.email.trim().toLowerCase()
//       : "unknown";
//   return `${req.ip}:${email}`;
// }

// module.exports = {
//   createRateLimiter,
//   ipAndEmailKey,
// };
// Provides in-memory request throttling for brute-force and abuse mitigation.
// Provides in-memory request throttling for brute-force and abuse mitigation.
const { AppError } = require("../common/errors/AppError");

const stores = new Map();

function getStore(name) {
  if (!stores.has(name)) stores.set(name, new Map());
  return stores.get(name);
}

function cleanupExpiredEntries(store, now) {
  for (const [key, value] of store.entries()) {
    const resetAt = value?.resetAt || 0;
    const blockedUntil = value?.blockedUntil || 0;
    if (resetAt <= now && blockedUntil <= now) {
      store.delete(key);
    }
  }
}

//  FIXED: safer + stronger key generation
function ipAndEmailKey(req) {
  // real IP (handles proxy / nginx / express trust proxy)
  const ip =
    req.headers["x-forwarded-for"]?.split(",")[0]?.trim() ||
    req.ip ||
    req.socket?.remoteAddress ||
    "unknown-ip";

  const email =
    typeof req.body?.email === "string"
      ? req.body.email.trim().toLowerCase()
      : "no-email";

  //  stronger composite key
  return `${ip}:${email}`;
}

function createRateLimiter({
  name,
  windowMs,
  max,
  blockDurationMs,
  keyGenerator,
  message,
  code,
}) {
  const resolvedName = name || "default";
  const resolvedWindowMs = Number(windowMs || 60_000);
  const resolvedMax = Number(max || 60);
  const resolvedBlockDurationMs = Number(blockDurationMs || resolvedWindowMs);
  const resolvedMessage = message || "Too many requests. Please try again later.";
  const resolvedCode = code || "RATE_LIMITED";

  return function rateLimiter(req, res, next) {
    const now = Date.now();
    const store = getStore(resolvedName);

    if (store.size > 10_000) {
      cleanupExpiredEntries(store, now);
    }

    const rawKey = keyGenerator ? keyGenerator(req) : req.ip;
    const key = String(rawKey || "unknown-key");

    const existing = store.get(key);

    //  blocked state
    if (existing?.blockedUntil && existing.blockedUntil > now) {
      const retryAfterSeconds = Math.max(
        1,
        Math.ceil((existing.blockedUntil - now) / 1000),
      );
      res.set("Retry-After", String(retryAfterSeconds));
      return next(new AppError(resolvedMessage, 429, resolvedCode));
    }

    //  new window
    if (!existing || existing.resetAt <= now) {
      store.set(key, {
        count: 1,
        resetAt: now + resolvedWindowMs,
        blockedUntil: 0,
      });
      return next();
    }

    existing.count += 1;

    //  limit exceeded
    if (existing.count > resolvedMax) {
      existing.blockedUntil = now + resolvedBlockDurationMs;

      const retryAfterSeconds = Math.max(
        1,
        Math.ceil((existing.blockedUntil - now) / 1000),
      );

      res.set("Retry-After", String(retryAfterSeconds));
      return next(new AppError(resolvedMessage, 429, resolvedCode));
    }

    store.set(key, existing);
    return next();
  };
}

module.exports = {
  createRateLimiter,
  ipAndEmailKey,
};