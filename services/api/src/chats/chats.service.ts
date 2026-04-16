import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { decryptText, encryptText } from './crypto';

@Injectable()
export class ChatsService {
  constructor(private prisma: PrismaService) {}

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

    // cursor = createdAt ISO; traemos mensajes anteriores a esa fecha
    const where: Prisma.MessageWhereInput = { matchId };
    if (cursor) {
      const dt = new Date(cursor);
      if (!Number.isNaN(dt.getTime())) {
        where.createdAt = { lt: dt };
      }
    }

    const rows = await this.prisma.message.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take,
      select: {
        id: true,
        matchId: true,
        senderId: true,
        ciphertext: true,
        createdAt: true,
        readAt: true,
      },
    });

    // devolvemos en orden asc (antiguo -> nuevo) para ListView
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

    const created = await this.prisma.message.create({
      data: {
        matchId,
        senderId: userId,
        ciphertext,
      },
      select: {
        id: true,
        matchId: true,
        senderId: true,
        ciphertext: true,
        createdAt: true,
        readAt: true,
      },
    });

    return {
      id: created.id,
      matchId: created.matchId,
      senderId: created.senderId,
      text: decryptText(created.ciphertext), // devuelve plaintext al cliente
      createdAt: created.createdAt,
      readAt: created.readAt,
    };
  }

  async markRead(matchId: string, userId: string) {
    await this.assertMember(matchId, userId);

    // marca como leídos TODOS los mensajes del otro usuario
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
