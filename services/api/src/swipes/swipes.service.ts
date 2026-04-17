import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateSwipeDto } from './dto';
import { Sport, SwipeType } from '@prisma/client';

@Injectable()
export class SwipesService {
  constructor(private readonly prisma: PrismaService) {}

  private orderPair(a: string, b: string, sport: Sport) {
    return a < b
      ? { userAId: a, userBId: b, sport }
      : { userAId: b, userBId: a, sport };
  }

  async createSwipe(fromUserId: string, dto: CreateSwipeDto) {
    if (dto.toUserId === fromUserId) {
      throw new BadRequestException('Cannot swipe yourself');
    }

    const swipe = await this.prisma.swipe.upsert({
      where: {
        fromUserId_toUserId_sport: {
          fromUserId,
          toUserId: dto.toUserId,
          sport: dto.sport,
        },
      },
      create: {
        fromUserId,
        toUserId: dto.toUserId,
        sport: dto.sport,
        type: dto.type,
      },
      update: { type: dto.type },
    });

    if (dto.type !== SwipeType.LIKE) {
      return { match: false, swipeId: swipe.id };
    }

    const reverse = await this.prisma.swipe.findFirst({
      where: {
        fromUserId: dto.toUserId,
        toUserId: fromUserId,
        type: SwipeType.LIKE,
        sport: dto.sport,
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!reverse) {
      return { match: false, swipeId: swipe.id };
    }

    const pair = this.orderPair(fromUserId, dto.toUserId, dto.sport);

    const match = await this.prisma.match.upsert({
      where: { userAId_userBId_sport: pair },
      create: pair,
      update: {},
    });

    return { match: true, matchId: match.id, swipeId: swipe.id };
  }
}
