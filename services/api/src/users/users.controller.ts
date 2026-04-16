import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { UsersService } from './users.service';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get(':userId/profile')
  getProfile(@Param('userId') userId: string) {
    return this.usersService.getUserProfileByUserId(userId);
  }
}
