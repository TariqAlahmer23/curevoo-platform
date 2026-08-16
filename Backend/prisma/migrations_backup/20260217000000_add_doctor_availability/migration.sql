-- AddDoctorAvailability Migration
-- Add isActive column to DoctorProfile
ALTER TABLE "DoctorProfile" ADD COLUMN "isActive" BOOLEAN NOT NULL DEFAULT true;

-- Create DoctorAvailableTime table
CREATE TABLE "DoctorAvailableTime" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "doctorId" TEXT NOT NULL,
    "dayOfWeek" INTEGER NOT NULL DEFAULT 0,
    "startTime" TEXT NOT NULL,
    "endTime" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "DoctorAvailableTime_doctorId_fkey" FOREIGN KEY ("doctorId") REFERENCES "DoctorProfile" ("id") ON DELETE CASCADE
);

-- Create unique constraint to prevent overlapping times
CREATE UNIQUE INDEX "DoctorAvailableTime_doctorId_dayOfWeek_startTime_endTime_key" ON "DoctorAvailableTime"("doctorId", "dayOfWeek", "startTime", "endTime");

-- Create index for faster queries
CREATE INDEX "DoctorAvailableTime_doctorId_idx" ON "DoctorAvailableTime"("doctorId");

-- Update migration_lock.toml for Prisma tracking (if needed)
