import { Sport, SwipeType } from '@prisma/client';

export class CreateSwipeDto {
  toUserId!: string;
  sport!: Sport;
  type!: SwipeType; // LIKE | PASS
}
