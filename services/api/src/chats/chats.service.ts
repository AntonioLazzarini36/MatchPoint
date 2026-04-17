import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { decryptText, encryptText } from './crypto';

const messageSelect = {
  id: true,
  matchId: true,
  senderId: true,
  ciphertext: true,
  createdAt: true,
  readAt: true,
} satisfies Prisma.MessageSelect;

type SelectedMessage = Prisma.MessageGetPayload<{
  select: typeof messageSelect;
}>;

@Injectable()
export class ChatsService {
  constructor(private readonly prisma: PrismaService) {}

  private async assertMember(matchId: string, userId: string) {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      select: { id: true, userAId: true, userBId: true },
    });

    if (!match) throw new NotFoundException('Match not found');

    const ok = match.userAId === userId || match.userBId === userId;
    if (!ok) throw new ForbiddenException('Not allowed');

    return match;
  }

  async listMessages(
    matchId: string,
    userId: string,
    limit = 50,
    cursor?: string,
  ) {
    await this.assertMember(matchId, userId);

    const take = Math.min(Math.max(limit, 1), 100);

    const where: Prisma.MessageWhereInput = { matchId };

    if (cursor) {
      const dt = new Date(cursor);
      if (!Number.isNaN(dt.getTime())) {
        where.createdAt = { lt: dt };
      }
    }

    const rows: SelectedMessage[] = await this.prisma.message.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take,
      select: messageSelect,
    });

    return rows.reverse().map((m) => ({
      id: m.id,
      matchId: m.matchId,
      senderId: m.senderId,
      text: decryptText(m.ciphertext),
      createdAt: m.createdAt,
      readAt: m.readAt,
    }));
  }

  async sendMessage(matchId: string, userId: string, text: string) {
    await this.assertMember(matchId, userId);

    const ciphertext = encryptText(text);

    const created: SelectedMessage = await this.prisma.message.create({
      data: {
        matchId,
        senderId: userId,
        ciphertext,
      },
      select: messageSelect,
    });

    return {
      id: created.id,
      matchId: created.matchId,
      senderId: created.senderId,
      text: decryptText(created.ciphertext),
      createdAt: created.createdAt,
      readAt: created.readAt,
    };
  }

  async markRead(matchId: string, userId: string) {
    await this.assertMember(matchId, userId);

    const now = new Date();

    const res = await this.prisma.message.updateMany({
      where: {
        matchId,
        senderId: { not: userId },
        readAt: null,
      },
      data: { readAt: now },
    });

    return { updated: res.count, readAt: now };
  }
}
