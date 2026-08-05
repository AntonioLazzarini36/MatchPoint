DROP TABLE IF EXISTS "EmailVerification";
ALTER TABLE "User" DROP COLUMN IF EXISTS "emailVerifiedAt";
