import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { UpdatePreferencesDto, UpdateProfileDto } from './dto';

@Injectable()
export class MeService {
  constructor(private prisma: PrismaService) {}

  async getMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        profile: true,
        preferences: true,
        createdAt: true,
      },
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    // upsert profile
    const profile = await this.prisma.profile.upsert({
      where: { userId },
      create: {
        userId,
        displayName: dto.displayName ?? 'Unknown',
        birthDate: dto.birthDate
          ? new Date(dto.birthDate)
          : new Date('2000-01-01'),
        city: dto.city ?? null,
        bio: dto.bio ?? null,
        photos: dto.photos ?? [],
        sports: dto.sports ?? [],
      },
      update: {
        displayName: dto.displayName ?? undefined,
        birthDate: dto.birthDate ? new Date(dto.birthDate) : undefined,
        city: dto.city ?? undefined,
        bio: dto.bio ?? undefined,
        photos: dto.photos ?? undefined,
        sports: dto.sports ?? undefined,
      },
    });

    return profile;
  }

  async updatePreferences(userId: string, dto: UpdatePreferencesDto) {
    const prefs = await this.prisma.preferences.upsert({
      where: { userId },
      create: {
        userId,
        sportsWanted: dto.sportsWanted ?? [],
        distanceKm: dto.distanceKm ?? 25,
        ageMin: dto.ageMin ?? 18,
        ageMax: dto.ageMax ?? 60,
        genderPreference: dto.genderPreference ?? null,
      },
      update: {
        sportsWanted: dto.sportsWanted ?? undefined,
        distanceKm: dto.distanceKm ?? undefined,
        ageMin: dto.ageMin ?? undefined,
        ageMax: dto.ageMax ?? undefined,
        genderPreference: dto.genderPreference ?? undefined,
      },
    });

    return prefs;
  }
}
