import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async getUserProfileByUserId(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
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
    });

    if (!user || !user.profile) {
      throw new NotFoundException('Profile not found');
    }

    // Forma parecida a DiscoverProfile para que el movil lo consuma facil
    return {
      userId: user.id,
      displayName: user.profile.displayName,
      birthDate: user.profile.birthDate,
      city: user.profile.city,
      bio: user.profile.bio,
      photos: user.profile.photos,
      sports: user.profile.sports,
    };
  }
}
