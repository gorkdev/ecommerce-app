import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { PrismaService } from '../prisma/prisma.service';

jest.mock('@node-rs/argon2', () => ({
  hash: jest.fn(async (pw: string) => `hashed:${pw}`),
  verify: jest.fn(async (digest: string, pw: string) => digest === `hashed:${pw}`),
}));

describe('AuthService', () => {
  let service: AuthService;
  let prisma: {
    user: { findUnique: jest.Mock; create: jest.Mock };
    refreshToken: {
      findUnique: jest.Mock;
      create: jest.Mock;
      delete: jest.Mock;
      deleteMany: jest.Mock;
    };
  };
  let jwt: { signAsync: jest.Mock; verifyAsync: jest.Mock; decode: jest.Mock };

  const baseUser = {
    id: 'user-1',
    email: 'a@b.com',
    name: 'Tester',
    role: 'CUSTOMER',
    passwordHash: 'hashed:secret123',
  };

  beforeEach(async () => {
    prisma = {
      user: { findUnique: jest.fn(), create: jest.fn() },
      refreshToken: {
        findUnique: jest.fn(),
        create: jest.fn(),
        delete: jest.fn(),
        deleteMany: jest.fn(),
      },
    };
    jwt = {
      signAsync: jest
        .fn()
        .mockResolvedValueOnce('access-token')
        .mockResolvedValueOnce('refresh-token'),
      verifyAsync: jest.fn(),
      decode: jest
        .fn()
        .mockReturnValue({ exp: Math.floor(Date.now() / 1000) + 3600 }),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: JwtService, useValue: jwt },
        {
          provide: ConfigService,
          useValue: {
            getOrThrow: jest.fn((key: string) => `secret-${key}`),
            get: jest.fn((key: string) =>
              key.endsWith('TTL') ? '15m' : undefined,
            ),
          },
        },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
  });

  describe('register', () => {
    it('hashes the password, persists the user and returns tokens', async () => {
      prisma.user.findUnique.mockResolvedValue(null);
      prisma.user.create.mockResolvedValue(baseUser);
      prisma.refreshToken.create.mockResolvedValue({});

      const result = await service.register('a@b.com', 'secret123', 'Tester');

      expect(prisma.user.create).toHaveBeenCalledWith({
        data: {
          email: 'a@b.com',
          name: 'Tester',
          passwordHash: 'hashed:secret123',
        },
      });
      expect(result.accessToken).toBe('access-token');
      expect(result.refreshToken).toBe('refresh-token');
      expect(result.user).toEqual({
        id: 'user-1',
        email: 'a@b.com',
        name: 'Tester',
        role: 'CUSTOMER',
      });
      // The password hash must never leak to the response.
      expect(result.user as unknown as Record<string, unknown>).not.toHaveProperty(
        'passwordHash',
      );
      expect(prisma.refreshToken.create).toHaveBeenCalledTimes(1);
    });

    it('rejects a duplicate email', async () => {
      prisma.user.findUnique.mockResolvedValue(baseUser);

      await expect(
        service.register('a@b.com', 'secret123', 'Tester'),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(prisma.user.create).not.toHaveBeenCalled();
    });
  });

  describe('login', () => {
    it('returns tokens for valid credentials', async () => {
      prisma.user.findUnique.mockResolvedValue(baseUser);
      prisma.refreshToken.create.mockResolvedValue({});

      const result = await service.login('a@b.com', 'secret123');

      expect(result.accessToken).toBe('access-token');
      expect(result.user.email).toBe('a@b.com');
    });

    it('throws when the user does not exist', async () => {
      prisma.user.findUnique.mockResolvedValue(null);

      await expect(service.login('x@y.com', 'secret123')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });

    it('throws when the password is wrong', async () => {
      prisma.user.findUnique.mockResolvedValue(baseUser);

      await expect(
        service.login('a@b.com', 'wrongpass'),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });
  });

  describe('refresh', () => {
    it('rotates a valid refresh token', async () => {
      jwt.verifyAsync.mockResolvedValue({ sub: 'user-1' });
      prisma.refreshToken.findUnique.mockResolvedValue({
        id: 'rt-1',
        userId: 'user-1',
        expiresAt: new Date(Date.now() + 60_000),
      });
      prisma.refreshToken.delete.mockResolvedValue({});
      prisma.user.findUnique.mockResolvedValue(baseUser);
      prisma.refreshToken.create.mockResolvedValue({});

      const result = await service.refresh('refresh-token');

      expect(prisma.refreshToken.delete).toHaveBeenCalledWith({
        where: { id: 'rt-1' },
      });
      expect(result.accessToken).toBe('access-token');
      expect(result.refreshToken).toBe('refresh-token');
    });

    it('rejects an invalid jwt', async () => {
      jwt.verifyAsync.mockRejectedValue(new Error('bad token'));

      await expect(service.refresh('bad')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });

    it('rejects a revoked / unknown token', async () => {
      jwt.verifyAsync.mockResolvedValue({ sub: 'user-1' });
      prisma.refreshToken.findUnique.mockResolvedValue(null);

      await expect(service.refresh('refresh-token')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });

    it('rejects an expired token', async () => {
      jwt.verifyAsync.mockResolvedValue({ sub: 'user-1' });
      prisma.refreshToken.findUnique.mockResolvedValue({
        id: 'rt-1',
        userId: 'user-1',
        expiresAt: new Date(Date.now() - 1_000),
      });

      await expect(service.refresh('refresh-token')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });
  });

  describe('logout', () => {
    it('deletes the stored refresh token', async () => {
      prisma.refreshToken.deleteMany.mockResolvedValue({ count: 1 });

      await service.logout('refresh-token');

      expect(prisma.refreshToken.deleteMany).toHaveBeenCalledTimes(1);
    });
  });
});
