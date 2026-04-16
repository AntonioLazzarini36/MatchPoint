import { Sport } from '@prisma/client';

export class UpdateProfileDto {
  displayName?: string;
  birthDate?: string; // "YYYY-MM-DD" o ISO
  city?: string;
  bio?: string;
  photos?: string[];
  sports?: Sport[];
}

export class UpdatePreferencesDto {
  sportsWanted?: Sport[];
  distanceKm?: number;
  ageMin?: number;
  ageMax?: number;
  genderPreference?: string;
}
