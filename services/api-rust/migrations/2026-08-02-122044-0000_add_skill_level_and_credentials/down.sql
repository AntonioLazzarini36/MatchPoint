-- This file should undo anything in `up.sql`
ALTER TABLE "Profile" DROP COLUMN achievements;
ALTER TABLE "Profile" DROP COLUMN club;
ALTER TABLE "Profile" DROP COLUMN "yearsPlaying";

DROP TABLE "SkillLevel";
DROP TYPE "SkillLevelValue";
