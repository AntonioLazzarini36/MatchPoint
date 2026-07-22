-- Your SQL goes here
-- Reconstructs the schema exactly as it exists today in the dev database
-- (originally built up through several Prisma migrations). From here on,
-- schema changes go through Diesel migrations instead.

CREATE TYPE "Sport" AS ENUM ('TENNIS', 'RUNNING');
CREATE TYPE "SwipeType" AS ENUM ('LIKE', 'PASS');

CREATE TABLE "User" (
                        id TEXT PRIMARY KEY,
                        email TEXT NOT NULL UNIQUE,
                        "passwordHash" TEXT NOT NULL,
                        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
                        "updatedAt" TIMESTAMPTZ NOT NULL
);

CREATE TABLE "Profile" (
                           id TEXT PRIMARY KEY,
                           "userId" TEXT NOT NULL UNIQUE REFERENCES "User"(id) ON DELETE CASCADE,
                           "displayName" TEXT NOT NULL,
                           "birthDate" TIMESTAMPTZ NOT NULL,
                           city TEXT,
                           bio TEXT,
                           photos TEXT[] NOT NULL DEFAULT '{}',
                           sports "Sport"[] NOT NULL DEFAULT '{}',
                           "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
                           "updatedAt" TIMESTAMPTZ NOT NULL
);

CREATE TABLE "Preferences" (
                               id TEXT PRIMARY KEY,
                               "userId" TEXT NOT NULL UNIQUE REFERENCES "User"(id) ON DELETE CASCADE,
                               "sportsWanted" "Sport"[] NOT NULL DEFAULT '{}',
                               "distanceKm" INT4 NOT NULL DEFAULT 25,
                               "ageMin" INT4 NOT NULL DEFAULT 18,
                               "ageMax" INT4 NOT NULL DEFAULT 60,
                               "genderPreference" TEXT,
                               "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
                               "updatedAt" TIMESTAMPTZ NOT NULL
);

CREATE TABLE "RefreshToken" (
                                id TEXT PRIMARY KEY,
                                "userId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
                                "tokenHash" TEXT NOT NULL,
                                "revokedAt" TIMESTAMPTZ,
                                "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE "Swipe" (
                         id TEXT PRIMARY KEY,
                         "fromUserId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
                         "toUserId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
                         sport "Sport" NOT NULL,
                         type "SwipeType" NOT NULL,
                         "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
                         UNIQUE ("fromUserId", "toUserId", sport)
);
CREATE INDEX "Swipe_toUserId_sport_idx" ON "Swipe" ("toUserId", sport);

CREATE TABLE "Match" (
                         id TEXT PRIMARY KEY,
                         "userAId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
                         "userBId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
                         sport "Sport" NOT NULL,
                         "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
                         UNIQUE ("userAId", "userBId", sport)
);
CREATE INDEX "Match_userAId_idx" ON "Match" ("userAId");
CREATE INDEX "Match_userBId_idx" ON "Match" ("userBId");

CREATE TABLE "Message" (
                           id TEXT PRIMARY KEY,
                           "matchId" TEXT NOT NULL REFERENCES "Match"(id) ON DELETE CASCADE,
                           "senderId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
                           ciphertext TEXT NOT NULL,
                           "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
                           "readAt" TIMESTAMPTZ
);
CREATE INDEX "Message_matchId_createdAt_idx" ON "Message" ("matchId", "createdAt");
CREATE INDEX "Message_senderId_idx" ON "Message" ("senderId");