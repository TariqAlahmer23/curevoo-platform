ALTER TYPE "AppointmentStatus" ADD VALUE IF NOT EXISTS 'CREATED';

ALTER TABLE "Appointment"
ADD COLUMN "createdPatientId" TEXT;

ALTER TABLE "Appointment"
ALTER COLUMN "patientUserId" DROP NOT NULL;

ALTER TABLE "Appointment"
ADD CONSTRAINT "Appointment_createdPatientId_fkey"
FOREIGN KEY ("createdPatientId") REFERENCES "CreatedPatient"("id")
ON DELETE CASCADE
ON UPDATE CASCADE;

CREATE INDEX "Appointment_createdPatientId_createdAt_idx"
ON "Appointment"("createdPatientId", "createdAt");

ALTER TABLE "Appointment"
ADD CONSTRAINT "Appointment_subject_check"
CHECK (
  ("patientUserId" IS NOT NULL AND "createdPatientId" IS NULL)
  OR
  ("patientUserId" IS NULL AND "createdPatientId" IS NOT NULL)
);
