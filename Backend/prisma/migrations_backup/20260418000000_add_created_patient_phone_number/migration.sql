-- Add optional phone number storage for doctor-created patients.
ALTER TABLE "CreatedPatient"
ADD COLUMN IF NOT EXISTS "phoneNumber" TEXT;
