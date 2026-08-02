-- Your SQL goes here
-- Running-specific credentials, alongside the tennis-oriented
-- yearsPlaying/club added in the previous migration — shown
-- conditionally on the client depending on which sports the user plays.
ALTER TABLE "Profile" ADD COLUMN "avgPaceMinPerKm" DOUBLE PRECISION;
ALTER TABLE "Profile" ADD COLUMN "avgDistanceKm" DOUBLE PRECISION;
