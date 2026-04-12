import { Injectable } from "@nestjs/common";
import { PrismaService } from "../../prisma/prisma.service";

@Injectable()
export class MatchesService {
  constructor(private prisma: PrismaService) {}

  async list(userId: string) {
    const matches = await this.prisma.match.findMany({
      where: {
        OR: [{ userAId: userId }, { userBId: userId }],
      },
      orderBy: { createdAt: "desc" },
      select: {
        id: true,
        createdAt: true,
        userAId: true,
        userBId: true,
        userA: { select: { id: true, profile: true } },
        userB: { select: { id: true, profile: true } },
      },
      take: 50,
    });

    return matches.map((m) => {
      const isA = m.userAId === userId;
      const me = isA ? m.userA : m.userB;
      const other = isA ? m.userB : m.userA;

      return {
        matchId: m.id,
        createdAt: m.createdAt,
        otherUser: {
          userId: other.id,
          profile: other.profile,
        },
        me: {
          userId: me.id,
          profile: me.profile,
        },
      };
    });
  }
}