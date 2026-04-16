import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { Sport } from '@prisma/client';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { AuthenticatedRequest } from '../auth/authenticated-request.type';
import { DiscoverService } from './discover.service';

@Controller('discover')
@UseGuards(JwtAuthGuard)
export class DiscoverController {
  constructor(private readonly discoverService: DiscoverService) {}

  @Get()
  discover(@Req() req: AuthenticatedRequest, @Query('sport') sport?: Sport) {
    return this.discoverService.discover(req.user.userId, sport);
  }
}
