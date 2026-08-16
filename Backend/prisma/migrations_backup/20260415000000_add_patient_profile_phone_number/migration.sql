-- Add the missing patient profile phone number column used by the API select.
ALTER TABLE "PatientProfile"
ADD COLUMN IF NOT EXISTS "phoneNumber" TEXT;
