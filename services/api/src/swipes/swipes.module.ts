import { Module } from '@nestjs/common';
import { SwipesController } from './swipes.controller';
import { SwipesService } from './swipes.service';

@Module({
  controllers: [SwipesController],
  providers: [SwipesService],
})
export class SwipesModule {}
