import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { AuthenticatedRequest } from '../auth/authenticated-request.type';
import { MatchesService } from './matches.service';

@Controller('matches')
@UseGuards(JwtAuthGuard)
export class MatchesController {
  constructor(private readonly matches: MatchesService) {}

  @Get()
  list(@Req() req: AuthenticatedRequest) {
    return this.matches.list(req.user.userId);
  }
}
