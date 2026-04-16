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
import { ChatsModule } from './chats/chats.module';
import { UsersModule } from './users/users.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    DiscoverModule,
    MeModule,
    AuthModule,
    SwipesModule,
    MatchesModule,
    ChatsModule,
    UsersModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
