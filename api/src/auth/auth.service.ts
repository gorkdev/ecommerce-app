import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { createHash, randomUUID } from 'node:crypto';
import type { StringValue } from 'ms';
import { hash as argonHash, verify as argonVerify } from '@node-rs/argon2';
import { PrismaService } from '../prisma/prisma.service';
import { JwtPayload, RefreshPayload } from './types/jwt-payload';

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface PublicUser {
  id: string;
  email: string;
  name: string;
  role: string;
}

export interface AuthResult extends AuthTokens {
  user: PublicUser;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async register(
    email: string,
    password: string,
    name: string,
  ): Promise<AuthResult> {
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) {
      throw new ConflictException('Email is already registered');
    }

    const passwordHash = await argonHash(password);
    const user = await this.prisma.user.create({
      data: { email, name, passwordHash },
    });

    const tokens = await this.issueTokens(user.id, user.email, user.role);
    return { user: this.toPublicUser(user), ...tokens };
  }

  async login(email: string, password: string): Promise<AuthResult> {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const valid = await argonVerify(user.passwordHash, password);
    if (!valid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const tokens = await this.issueTokens(user.id, user.email, user.role);
    return { user: this.toPublicUser(user), ...tokens };
  }

  async refresh(refreshToken: string): Promise<AuthTokens> {
    let payload: RefreshPayload;
    try {
      payload = await this.jwt.verifyAsync<RefreshPayload>(refreshToken, {
        secret: this.config.getOrThrow<string>('JWT_REFRESH_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const tokenHash = this.hashToken(refreshToken);
    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
    });
    if (
      !stored ||
      stored.userId !== payload.sub ||
      stored.expiresAt.getTime() < Date.now()
    ) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    // Rotation: a refresh token can only be used once.
    await this.prisma.refreshToken.delete({ where: { id: stored.id } });

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
    });
    if (!user) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    return this.issueTokens(user.id, user.email, user.role);
  }

  async logout(refreshToken: string): Promise<void> {
    const tokenHash = this.hashToken(refreshToken);
    await this.prisma.refreshToken.deleteMany({ where: { tokenHash } });
  }

  async getProfile(userId: string): Promise<PublicUser> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException();
    }
    return this.toPublicUser(user);
  }

  private async issueTokens(
    userId: string,
    email: string,
    role: JwtPayload['role'],
  ): Promise<AuthTokens> {
    const accessToken = await this.jwt.signAsync(
      { sub: userId, email, role } satisfies JwtPayload,
      {
        secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
        expiresIn: (this.config.get<string>('JWT_ACCESS_TTL') ??
          '15m') as StringValue,
      },
    );

    const refreshToken = await this.jwt.signAsync(
      { sub: userId, jti: randomUUID() } satisfies RefreshPayload,
      {
        secret: this.config.getOrThrow<string>('JWT_REFRESH_SECRET'),
        expiresIn: (this.config.get<string>('JWT_REFRESH_TTL') ??
          '7d') as StringValue,
      },
    );

    const decoded = this.jwt.decode(refreshToken) as { exp: number };
    await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash: this.hashToken(refreshToken),
        expiresAt: new Date(decoded.exp * 1000),
      },
    });

    return { accessToken, refreshToken };
  }

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private toPublicUser(user: {
    id: string;
    email: string;
    name: string;
    role: string;
  }): PublicUser {
    return { id: user.id, email: user.email, name: user.name, role: user.role };
  }
}
