import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from '../prisma/prisma.module';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { DiscoverModule } from './discover/discover.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    DiscoverModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}