-- Allow care records to belong to either a real patient account or a doctor-created patient.

ALTER TABLE "TreatmentPlan"
ADD COLUMN "createdPatientId" TEXT,
ALTER COLUMN "patientUserId" DROP NOT NULL;

ALTER TABLE "MedicalHistory"
ADD COLUMN "createdPatientId" TEXT,
ALTER COLUMN "patientUserId" DROP NOT NULL;

ALTER TABLE "MedicalHistoryUpdateRequest"
ALTER COLUMN "patientUserId" DROP NOT NULL;

ALTER TABLE "TreatmentPlan"
ADD CONSTRAINT "TreatmentPlan_createdPatientId_fkey"
FOREIGN KEY ("createdPatientId") REFERENCES "CreatedPatient"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "MedicalHistory"
ADD CONSTRAINT "MedicalHistory_createdPatientId_fkey"
FOREIGN KEY ("createdPatientId") REFERENCES "CreatedPatient"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

CREATE INDEX "TreatmentPlan_createdPatientId_createdAt_idx"
ON "TreatmentPlan"("createdPatientId", "createdAt");

CREATE INDEX "MedicalHistory_createdPatientId_createdAt_idx"
ON "MedicalHistory"("createdPatientId", "createdAt");

ALTER TABLE "TreatmentPlan"
ADD CONSTRAINT "TreatmentPlan_patient_subject_check"
CHECK (
  ("patientUserId" IS NOT NULL AND "createdPatientId" IS NULL) OR
  ("patientUserId" IS NULL AND "createdPatientId" IS NOT NULL)
);

ALTER TABLE "MedicalHistory"
ADD CONSTRAINT "MedicalHistory_patient_subject_check"
CHECK (
  ("patientUserId" IS NOT NULL AND "createdPatientId" IS NULL) OR
  ("patientUserId" IS NULL AND "createdPatientId" IS NOT NULL)
);
