import { Body, Controller, Get, Param, Patch, Post, Query, Req, UseGuards } from "@nestjs/common";
import { JwtAuthGuard } from "../auth/jwt.guard";
import { ChatsService } from "./chats.service";
import { SendMessageDto } from "./dto";

@Controller("chats")
@UseGuards(JwtAuthGuard)
export class ChatsController {
  constructor(private readonly chats: ChatsService) {}

  @Get(":matchId/messages")
  listMessages(
    @Req() req: any,
    @Param("matchId") matchId: string,
    @Query("limit") limit?: string,
    @Query("cursor") cursor?: string,
  ) {
    const userId = req.user.userId;
    const lim = limit ? Number(limit) : 50;
    return this.chats.listMessages(matchId, userId, lim, cursor);
  }

  @Post(":matchId/messages")
  sendMessage(@Req() req: any, @Param("matchId") matchId: string, @Body() dto: SendMessageDto) {
    return this.chats.sendMessage(matchId, req.user.userId, dto.text);
  }

  @Patch(":matchId/read")
  markRead(@Req() req: any, @Param("matchId") matchId: string) {
    return this.chats.markRead(matchId, req.user.userId);
  }
}