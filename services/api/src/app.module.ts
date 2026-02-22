import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { AppController } from './app.controller';
import { AppService } from './app.service';

import { PrismaModule } from '../prisma/prisma.module';
import { DiscoverModule } from './discover/discover.module';
import { MeModule } from './me/me.module';
import { AuthModule } from './auth/auth.module';
import { SwipesModule } from './swipes/swipes.module';
import { MatchesModule } from './matches/matches.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    DiscoverModule,
    MeModule,
    AuthModule,
    SwipesModule,
    MatchesModule
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}