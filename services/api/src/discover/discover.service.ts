import { Injectable } from "@nestjs/common";
import { PrismaService } from "../../prisma/prisma.service";
import { Sport } from "@prisma/client";

@Injectable()
export class DiscoverService {
  constructor(private prisma: PrismaService) {}

  async discover(currentUserId: string, sport?: Sport) {
    const users = await this.prisma.user.findMany({
      where: {
        id: { not: currentUserId },
        profile: {
          is: {
            ...(sport ? { sports: { has: sport } } : {}),
          },
        },
      },
      select: {
        id: true,
        profile: {
          select: {
            displayName: true,
            birthDate: true,
            city: true,
            bio: true,
            photos: true,
            sports: true,
          },
        },
      },
      take: 20,
    });

    return users
      .filter((u) => u.profile)
      .map((u) => ({
        userId: u.id,
        displayName: u.profile!.displayName,
        birthDate: u.profile!.birthDate,
        city: u.profile!.city,
        bio: u.profile!.bio,
        photos: u.profile!.photos,
        sports: u.profile!.sports,
      }));
  }
}