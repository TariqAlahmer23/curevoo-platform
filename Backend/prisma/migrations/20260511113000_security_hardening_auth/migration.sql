-- Add OTP hardening fields
ALTER TABLE "OtpCode"
ADD COLUMN "otpHash" TEXT,
ADD COLUMN "attempts" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN "lockedUntil" TIMESTAMP(3);

-- Invalidate legacy plaintext OTP rows and mark them as used
UPDATE "OtpCode"
SET "otpHash" = 'LEGACY_INVALIDATED',
    "usedAt" = COALESCE("usedAt", NOW())
WHERE "otpHash" IS NULL;

ALTER TABLE "OtpCode"
ALTER COLUMN "otpHash" SET NOT NULL;

ALTER TABLE "OtpCode"
DROP COLUMN "otp";

-- Add refresh token session revocation/rotation store
CREATE TABLE "RefreshTokenSession" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "jti" TEXT NOT NULL,
    "userAgent" TEXT,
    "ipAddress" TEXT,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "revokedAt" TIMESTAMP(3),
    "replacedByJti" TEXT,
    "revokeReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RefreshTokenSession_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "RefreshTokenSession_jti_key" ON "RefreshTokenSession"("jti");
CREATE INDEX "RefreshTokenSession_userId_revokedAt_expiresAt_idx" ON "RefreshTokenSession"("userId", "revokedAt", "expiresAt");
CREATE INDEX "RefreshTokenSession_expiresAt_idx" ON "RefreshTokenSession"("expiresAt");

ALTER TABLE "RefreshTokenSession"
ADD CONSTRAINT "RefreshTokenSession_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
