ALTER TABLE "Preferences"
    ALTER COLUMN "genderPreference" TYPE TEXT
    USING "genderPreference"::TEXT;

ALTER TABLE "Profile" DROP COLUMN gender;

DROP TYPE "Gender";
