CREATE TYPE "ProposalStatus" AS ENUM ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED');

-- A concrete plan to actually play, tied to an existing match.
--
-- Until now a "proposal" was just a plain chat message (see the tennis
-- courts map and the running flow): no state, nothing the other side could
-- accept, and impossible to list as an upcoming session -- it scrolled
-- away like any other message. Making it a real row is what turns
-- MatchPoint from "you matched" into "you have a game on Thursday", and
-- it's also the hook a future rating system needs (a played, accepted
-- session is the thing whose result you'd record).
CREATE TABLE "Proposal" (
    id TEXT PRIMARY KEY,
    "matchId" TEXT NOT NULL REFERENCES "Match"(id) ON DELETE CASCADE,
    "proposedById" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
    sport "Sport" NOT NULL,
    -- Free-form place, mirroring how the rest of the app stores locations
    -- (`Profile.city` doubles as the display name of a picked place).
    -- Coordinates are optional: a tennis club picked from the map has them,
    -- "en el parque" typed by hand does not.
    "placeName" TEXT,
    "placeLat" DOUBLE PRECISION,
    "placeLng" DOUBLE PRECISION,
    "scheduledAt" TIMESTAMPTZ NOT NULL,
    status "ProposalStatus" NOT NULL DEFAULT 'PENDING',
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
    "updatedAt" TIMESTAMPTZ NOT NULL
);

CREATE INDEX "Proposal_matchId_idx" ON "Proposal" ("matchId");
-- Supports "my upcoming sessions", which sorts by date across all matches.
CREATE INDEX "Proposal_scheduledAt_idx" ON "Proposal" ("scheduledAt");
