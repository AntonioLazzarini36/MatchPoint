import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';

type JwtPayload = { sub: string; email: string };

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(cfg: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: cfg.get<string>('JWT_ACCESS_SECRET') ?? 'dev_access_secret',
    });
  }

  validate(payload: JwtPayload) {
    // Lo que devuelvas aqui aparece en req.user
    return { userId: payload.sub, email: payload.email };
  }
}
