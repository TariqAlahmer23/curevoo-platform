-- Align appointment statuses to the pending/confirmed/canceled workflow
ALTER TABLE "Appointment"
ALTER COLUMN "status" DROP DEFAULT;

CREATE TYPE "AppointmentStatus_new" AS ENUM ('PENDING', 'CONFIRMED', 'CANCELED');

ALTER TABLE "Appointment"
ALTER COLUMN "status" TYPE "AppointmentStatus_new"
USING (
  CASE
    WHEN "status"::text = 'BOOKED' THEN 'CONFIRMED'
    WHEN "status"::text = 'REJECTED' THEN 'CANCELED'
    ELSE "status"::text
  END
)::"AppointmentStatus_new";

DROP TYPE "AppointmentStatus";

ALTER TYPE "AppointmentStatus_new" RENAME TO "AppointmentStatus";

ALTER TABLE "Appointment"
ALTER COLUMN "status" SET DEFAULT 'PENDING';
