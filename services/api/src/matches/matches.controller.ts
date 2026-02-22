import { Controller, Get, Req, UseGuards } from "@nestjs/common";
import { JwtAuthGuard } from "../auth/jwt.guard";
import { MatchesService } from "./matches.service";

@Controller("matches")
@UseGuards(JwtAuthGuard)
export class MatchesController {
  constructor(private readonly matches: MatchesService) {}

  @Get()
  list(@Req() req: any) {
    return this.matches.list(req.user.userId);
  }
}