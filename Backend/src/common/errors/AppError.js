// Standard application error with HTTP status and machine-readable code.
class AppError extends Error {
  constructor(message, statusCode = 400, code = "APP_ERROR") {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
  }
}
module.exports = { AppError };
