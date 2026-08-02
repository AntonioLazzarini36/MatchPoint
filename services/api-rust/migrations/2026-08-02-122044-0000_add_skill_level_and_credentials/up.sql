-- Your SQL goes here
CREATE TYPE "SkillLevelValue" AS ENUM ('BEGINNER', 'INTERMEDIATE', 'ADVANCED', 'COMPETITIVE');

-- Self-reported, one row per (user, sport) — a player can be advanced at
-- tennis and a beginner runner, so this can't live as a single scalar on
-- Profile. Not a computed rating (no Elo/Glicko yet, see status.md).
CREATE TABLE "SkillLevel" (
    id TEXT PRIMARY KEY,
    "userId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
    sport "Sport" NOT NULL,
    level "SkillLevelValue" NOT NULL,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
    "updatedAt" TIMESTAMPTZ NOT NULL,
    UNIQUE ("userId", sport)
);
CREATE INDEX "SkillLevel_userId_idx" ON "SkillLevel" ("userId");

-- Structured trust signals shown on the profile/preview so the other
-- person has something to judge "plays my level" on beyond a free-text
-- bio: how long they've played, what club, notable results.
ALTER TABLE "Profile" ADD COLUMN "yearsPlaying" INT4;
ALTER TABLE "Profile" ADD COLUMN club TEXT;
ALTER TABLE "Profile" ADD COLUMN achievements TEXT[] NOT NULL DEFAULT '{}';
