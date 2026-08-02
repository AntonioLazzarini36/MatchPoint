-- This file should undo anything in `up.sql`
ALTER TABLE "Profile" DROP COLUMN "avgDistanceKm";
ALTER TABLE "Profile" DROP COLUMN "avgPaceMinPerKm";
