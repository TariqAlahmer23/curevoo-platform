// Configures the Express middleware stack and mounts the API modules.
require("dotenv").config();
const express = require("express");
const path = require("path");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const cookieParser = require("cookie-parser");

const { errorMiddleware } = require("./middlewares/error.middleware");
const { AppError } = require("./common/errors/AppError");
const { protectUploads } = require("./middlewares/uploads-access.middleware");

const authRoutes = require("./modules/auth/auth.routes");
const registrationRoutes = require("./modules/registration/registration.routes");
const patientRoutes = require("./modules/patients/patients.routes");
const doctorAppointmentRoutes = require("./modules/appointments/appointments-doctor.routes");
const doctorRoutes = require("./modules/doctors/doctor.routes");
const doctorPatientRoutes = require("./modules/doctors/doctor-patient.routes");
const careRoutes = require("./modules/care/care.routes");
const aiRoutes = require("./modules/ai/ai.routes");
const psychologicalSupportRoutes = require("./modules/psychological-support/psychological-support.routes");
const psychologicalAdminRoutes = require("./modules/psychological-support/psychological-admin.routes");
const adminUserRoutes = require("./modules/admin-users/admin-users.routes");

const app = express();

app.set("trust proxy", process.env.TRUST_PROXY === "1");

const defaultAllowedOrigins = [
  "http://localhost:3000",
  "http://127.0.0.1:3000",
  "http://localhost:5173",
  "http://127.0.0.1:5173",
];
const allowedOrigins = (process.env.CORS_ALLOWED_ORIGINS || defaultAllowedOrigins.join(","))
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);

app.use(helmet());
app.use(
  cors({
    origin(origin, callback) {
      if (!origin) return callback(null, true);
      if (allowedOrigins.includes(origin)) return callback(null, true);
      return callback(new AppError("CORS origin is not allowed", 403, "CORS_FORBIDDEN"));
    },
    credentials: true,
  }),
);
app.use(express.json({ limit: "2mb" }));
app.use(cookieParser());
app.use(morgan("dev"));
app.use("/uploads", protectUploads, express.static(path.join(__dirname, "uploads")));

// Describes the service at the API root so opening it in a browser is self-explanatory.
app.get("/", (req, res) =>
  res.json({
    service: "curevoo-backend",
    status: "ok",
    message: "This is a JSON API, not the web application.",
    endpoints: { health: "/health", api: "/api" },
  }),
);

app.get("/health", (req, res) => res.json({ ok: true }));

app.use("/api/auth", authRoutes);
app.use("/api/registration", registrationRoutes);
app.use("/api/patients", patientRoutes);
app.use("/api/doctor/appointments", doctorAppointmentRoutes);
app.use("/api/doctor", doctorRoutes);
app.use("/api/doctors", doctorPatientRoutes);
app.use("/api/care", careRoutes);
app.use("/api/ai", aiRoutes);
app.use("/api/patient/psychological-support", psychologicalSupportRoutes);
app.use("/api/admin/knowledge-articles", psychologicalAdminRoutes);
app.use("/api/admin/users", adminUserRoutes);

app.use(errorMiddleware);

module.exports = { app };
