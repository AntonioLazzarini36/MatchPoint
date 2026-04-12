import { Module } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { ChatsController } from './chats.controller';
import { ChatsService } from './chats.service';

@Module({
  controllers: [ChatsController],
  providers: [ChatsService, PrismaService],
})
export class ChatsModule {}
