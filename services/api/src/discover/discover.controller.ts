import { Controller, Get, Query } from "@nestjs/common";
import { Sport } from "@prisma/client";
import { DiscoverService } from "./discover.service";

@Controller("discover")
export class DiscoverController {
  constructor(private readonly discoverService: DiscoverService) {}

  @Get()
  discover(@Query("sport") sport?: Sport) {
    return this.discoverService.discover(sport);
  }
}