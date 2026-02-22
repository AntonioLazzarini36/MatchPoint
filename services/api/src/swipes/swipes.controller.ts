import { Body, Controller, Post, Req, UseGuards } from "@nestjs/common";
import { JwtAuthGuard } from "../auth/jwt.guard";
import { SwipesService } from "./swipes.service";
import { CreateSwipeDto } from "./dto";

@Controller("swipes")
@UseGuards(JwtAuthGuard)
export class SwipesController {
  constructor(private readonly swipes: SwipesService) {}

  @Post()
  create(@Req() req: any, @Body() dto: CreateSwipeDto) {
    return this.swipes.createSwipe(req.user.userId, dto);
  }
}