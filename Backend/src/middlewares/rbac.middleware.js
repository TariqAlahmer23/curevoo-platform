// Guards routes by checking the authenticated user's role.
const { AppError } = require("../common/errors/AppError");

// Rejects authenticated users whose role is not allowed for the route.
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user) return next(new AppError("Unauthorized", 401, "UNAUTHORIZED"));
    if (!roles.includes(req.user.role)) {
      return next(new AppError("Forbidden", 403, "FORBIDDEN"));
    }
    next();
  };
}

module.exports = { requireRole };
