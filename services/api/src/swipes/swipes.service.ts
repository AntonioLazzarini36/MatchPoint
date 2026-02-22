import { BadRequestException, Injectable } from "@nestjs/common";
import { PrismaService } from "../../prisma/prisma.service";
import { CreateSwipeDto } from "./dto";
import { SwipeType } from "@prisma/client";

@Injectable()
export class SwipesService {
  constructor(private prisma: PrismaService) {}

  private orderPair(a: string, b: string) {
    return a < b ? { userAId: a, userBId: b } : { userAId: b, userBId: a };
  }

  async createSwipe(fromUserId: string, dto: CreateSwipeDto) {
    if (dto.toUserId === fromUserId) {
      throw new BadRequestException("Cannot swipe yourself");
    }

    // Upsert del swipe (si ya existe, lo actualizamos)
    const swipe = await this.prisma.swipe.upsert({
      where: { fromUserId_toUserId_sport: { fromUserId, toUserId: dto.toUserId, sport: dto.sport } },
      create: {
        fromUserId,
        toUserId: dto.toUserId,
        sport: dto.sport,
        type: dto.type,
      },
      update: { type: dto.type },
    });

    // Solo hay match si es LIKE
    if (dto.type !== SwipeType.LIKE) {
      return { match: false, swipeId: swipe.id };
    }

    // ¿Existe like contrario?
    const reverse = await this.prisma.swipe.findUnique({
      where: { fromUserId_toUserId_sport: { fromUserId: dto.toUserId, toUserId: fromUserId, sport: dto.sport } },
    });

    if (!reverse || reverse.type !== SwipeType.LIKE) {
      return { match: false, swipeId: swipe.id };
    }

    // Crear match (con ids ordenados para evitar duplicados)
    const pair = this.orderPair(fromUserId, dto.toUserId);

    const match = await this.prisma.match.upsert({
      where: { userAId_userBId_sport: { ...pair, sport: dto.sport } },
      create: { ...pair, sport: dto.sport },
      update: {}, // ya existe
    });

    return { match: true, matchId: match.id, swipeId: swipe.id };
  }
}