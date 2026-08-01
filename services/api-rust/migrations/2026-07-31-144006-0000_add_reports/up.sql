-- Your SQL goes here
CREATE TABLE "Report" (
    id TEXT PRIMARY KEY,
    "reporterUserId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
    "reportedUserId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX "Report_reportedUserId_idx" ON "Report" ("reportedUserId");
