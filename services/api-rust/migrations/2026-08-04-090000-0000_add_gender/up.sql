CREATE TYPE "Gender" AS ENUM ('MALE', 'FEMALE', 'OTHER');

-- Who the user is. Nullable on purpose: profiles created before this
-- migration have none, and the onboarding step offers "prefiero no decirlo".
ALTER TABLE "Profile" ADD COLUMN gender "Gender";

-- `Preferences.genderPreference` has existed as free text since the Prisma
-- schema, but /discover never applied it -- there was no gender on Profile
-- to filter against, so it was a setting that did nothing. Now that the
-- column exists, normalise the preference to the same enum. NULL keeps
-- meaning "anyone".
UPDATE "Preferences" SET "genderPreference" = CASE
    WHEN "genderPreference" IN ('MALE', 'Hombres', 'Hombre') THEN 'MALE'
    WHEN "genderPreference" IN ('FEMALE', 'Mujeres', 'Mujer') THEN 'FEMALE'
    WHEN "genderPreference" IN ('OTHER', 'Otro', 'Otros') THEN 'OTHER'
    ELSE NULL
END;

ALTER TABLE "Preferences"
    ALTER COLUMN "genderPreference" TYPE "Gender"
    USING "genderPreference"::"Gender";
