import { Sport } from "@prisma/client";

export class RegisterDto {
  email!: string;
  password!: string;

  // opcionales para crear perfil rápido
  displayName?: string;
  birthDate?: string; // ISO string o "YYYY-MM-DD"
  city?: string;
  bio?: string;

  // opcionales
  sports?: Sport[];
  sportsWanted?: Sport[];
  distanceKm?: number;
  ageMin?: number;
  ageMax?: number;
  genderPreference?: string;
}

export class LoginDto {
  email!: string;
  password!: string;
}

export class RefreshDto {
  refreshToken!: string;
}

export class LogoutDto {
  refreshToken!: string;
}