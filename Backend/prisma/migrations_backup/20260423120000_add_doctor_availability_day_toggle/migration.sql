-- Allow doctor availability to store disabled days and frontend from/to schedules
ALTER TABLE "DoctorAvailableTime"
ADD COLUMN "isOn" BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE "DoctorAvailableTime"
ALTER COLUMN "startTime" DROP NOT NULL;

ALTER TABLE "DoctorAvailableTime"
ALTER COLUMN "endTime" DROP NOT NULL;
