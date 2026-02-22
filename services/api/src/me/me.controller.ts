import { Body, Controller, Get, Patch, Req, UseGuards } from "@nestjs/common";
import { JwtAuthGuard } from "../auth/jwt.guard";
import { MeService } from "./me.service";
import { UpdatePreferencesDto, UpdateProfileDto } from "./dto";

@Controller("me")
@UseGuards(JwtAuthGuard)
export class MeController {
  constructor(private readonly me: MeService) {}

  @Get()
  getMe(@Req() req: any) {
    return this.me.getMe(req.user.userId);
  }

  @Patch("profile")
  updateProfile(@Req() req: any, @Body() dto: UpdateProfileDto) {
    return this.me.updateProfile(req.user.userId, dto);
  }

  @Patch("preferences")
  updatePreferences(@Req() req: any, @Body() dto: UpdatePreferencesDto) {
    return this.me.updatePreferences(req.user.userId, dto);
  }
}