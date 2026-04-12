import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import * as bcrypt from 'bcrypt';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { RegisterDto, LoginDto } from './dto';

type JwtPayload = { sub: string; email: string };

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private cfg: ConfigService,
  ) {}

  private accessSecret() {
    return this.cfg.get<string>('JWT_ACCESS_SECRET') ?? 'dev_access_secret';
  }
  private refreshSecret() {
    return this.cfg.get<string>('JWT_REFRESH_SECRET') ?? 'dev_refresh_secret';
  }
  private accessExpiresInSeconds() {
    return Number(this.cfg.get<string>('JWT_ACCESS_EXPIRES_IN_SECONDS') ?? 900);
  }
  private refreshExpiresInSeconds() {
    return Number(
      this.cfg.get<string>('JWT_REFRESH_EXPIRES_IN_SECONDS') ?? 2592000,
    );
  }

  private async issueTokens(userId: string, email: string) {
    const payload: JwtPayload = { sub: userId, email };

    const accessToken = await this.jwt.signAsync(payload, {
      secret: this.accessSecret(),
      expiresIn: this.accessExpiresInSeconds(),
    });

    const refreshToken = await this.jwt.signAsync(payload, {
      secret: this.refreshSecret(),
      expiresIn: this.refreshExpiresInSeconds(),
    });

    // Guardamos hash del refresh token
    const tokenHash = await bcrypt.hash(refreshToken, 10);

    // Para MVP: 1 refresh activo por usuario (limpiamos anteriores)
    await this.prisma.refreshToken.deleteMany({ where: { userId } });
    await this.prisma.refreshToken.create({
      data: { userId, tokenHash },
    });

    return { accessToken, refreshToken };
  }

  async register(dto: RegisterDto) {
    const email = dto.email.trim().toLowerCase();

    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) throw new BadRequestException('Email already in use');

    const passwordHash = await bcrypt.hash(dto.password, 10);

    const user = await this.prisma.user.create({
      data: {
        email,
        passwordHash,
        profile:
          dto.displayName && dto.birthDate
            ? {
                create: {
                  displayName: dto.displayName,
                  birthDate: new Date(dto.birthDate),
                  city: dto.city ?? null,
                  bio: dto.bio ?? null,
                  photos: [],
                  sports: dto.sports ?? [],
                },
              }
            : undefined,
        preferences: {
          create: {
            sportsWanted: dto.sportsWanted ?? [],
            distanceKm: dto.distanceKm ?? 25,
            ageMin: dto.ageMin ?? 18,
            ageMax: dto.ageMax ?? 60,
            genderPreference: dto.genderPreference ?? null,
          },
        },
      },
      select: { id: true, email: true },
    });

    const tokens = await this.issueTokens(user.id, user.email);
    return { userId: user.id, ...tokens };
  }

  async login(dto: LoginDto) {
    const email = dto.email.trim().toLowerCase();
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) throw new UnauthorizedException('Invalid credentials');

    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) throw new UnauthorizedException('Invalid credentials');

    const tokens = await this.issueTokens(user.id, user.email);
    return { userId: user.id, ...tokens };
  }

  async refresh(refreshToken: string) {
    if (!refreshToken) throw new UnauthorizedException('Missing refresh token');

    let payload: JwtPayload;
    try {
      payload = await this.jwt.verifyAsync(refreshToken, {
        secret: this.refreshSecret(),
      });
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const stored = await this.prisma.refreshToken.findFirst({
      where: { userId: payload.sub, revokedAt: null },
      orderBy: { createdAt: 'desc' },
    });
    if (!stored) throw new UnauthorizedException('Refresh token revoked');

    const ok = await bcrypt.compare(refreshToken, stored.tokenHash);
    if (!ok) throw new UnauthorizedException('Refresh token mismatch');

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
    });
    if (!user) throw new UnauthorizedException('User not found');

    const tokens = await this.issueTokens(user.id, user.email);
    return { userId: user.id, ...tokens };
  }

  async logout(refreshToken: string) {
    if (!refreshToken) return { ok: true };

    try {
      const payload = await this.jwt.verifyAsync<JwtPayload>(refreshToken, {
        secret: this.refreshSecret(),
      });
      // Revoke all tokens for that user (MVP simple)
      await this.prisma.refreshToken.updateMany({
        where: { userId: payload.sub, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    } catch {
      // si es inválido, igual respondemos ok
    }

    return { ok: true };
  }
}
