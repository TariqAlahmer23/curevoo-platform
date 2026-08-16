-- CreateTable
CREATE TABLE "ai_nsclc_prediction_runs_created" (
    "id" TEXT NOT NULL,
    "created_patient_id" TEXT NOT NULL,
    "doctor_id" TEXT NOT NULL,
    "prediction_version" TEXT,
    "request_payload_json" JSONB NOT NULL,
    "response_json" JSONB,
    "summary_text" TEXT,
    "early_failure_probability" DOUBLE PRECISION,
    "early_failure_risk_level" TEXT,
    "durable_benefit_probability" DOUBLE PRECISION,
    "durable_benefit_risk_level" TEXT,
    "interpretation_summary" TEXT,
    "llm_explanation_enabled" BOOLEAN NOT NULL DEFAULT false,
    "status" TEXT NOT NULL,
    "error_message" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_nsclc_prediction_runs_created_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ai_nsclc_prediction_runs_created_created_patient_id_created_at_idx"
ON "ai_nsclc_prediction_runs_created"("created_patient_id", "created_at");

-- CreateIndex
CREATE INDEX "ai_nsclc_prediction_runs_created_doctor_id_created_at_idx"
ON "ai_nsclc_prediction_runs_created"("doctor_id", "created_at");

-- CreateIndex
CREATE INDEX "ai_nsclc_prediction_runs_created_status_created_at_idx"
ON "ai_nsclc_prediction_runs_created"("status", "created_at");

-- AddForeignKey
ALTER TABLE "ai_nsclc_prediction_runs_created"
ADD CONSTRAINT "ai_nsclc_prediction_runs_created_created_patient_id_fkey"
FOREIGN KEY ("created_patient_id") REFERENCES "CreatedPatient"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_nsclc_prediction_runs_created"
ADD CONSTRAINT "ai_nsclc_prediction_runs_created_doctor_id_fkey"
FOREIGN KEY ("doctor_id") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
