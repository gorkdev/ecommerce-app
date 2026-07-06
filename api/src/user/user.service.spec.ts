import { Test } from '@nestjs/testing';
import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { UserService } from './user.service';
import { PrismaService } from '../prisma/prisma.service';
import { Role } from '../generated/prisma/client';

type PrismaMock = {
  user: {
    findMany: jest.Mock;
    findUnique: jest.Mock;
    update: jest.Mock;
    count: jest.Mock;
  };
  $transaction: jest.Mock;
};

describe('UserService', () => {
  let service: UserService;
  let prisma: PrismaMock;

  beforeEach(async () => {
    prisma = {
      user: {
        findMany: jest.fn().mockResolvedValue([]),
        findUnique: jest.fn(),
        update: jest.fn(),
        count: jest.fn().mockResolvedValue(0),
      },
      $transaction: jest.fn((arg) =>
        Array.isArray(arg) ? Promise.all(arg) : arg(prisma),
      ),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [UserService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    service = moduleRef.get(UserService);
  });

  describe('findAll', () => {
    it('never selects the password hash', async () => {
      await service.findAll({});

      const select = prisma.user.findMany.mock.calls[0][0].select;
      expect(select.passwordHash).toBeUndefined();
      expect(select.id).toBe(true);
      expect(select._count).toEqual({
        select: { orders: true, reviews: true },
      });
    });

    it('builds a case-insensitive search across email and name', async () => {
      await service.findAll({ search: 'ann' });

      const where = prisma.user.findMany.mock.calls[0][0].where;
      expect(where.OR).toEqual([
        { email: { contains: 'ann', mode: 'insensitive' } },
        { name: { contains: 'ann', mode: 'insensitive' } },
      ]);
    });

    it('filters by role when supplied', async () => {
      await service.findAll({ role: Role.ADMIN });

      const where = prisma.user.findMany.mock.calls[0][0].where;
      expect(where.role).toBe(Role.ADMIN);
    });

    it('caps the page size at 100', async () => {
      await service.findAll({ limit: 500 });

      expect(prisma.user.findMany.mock.calls[0][0].take).toBe(100);
    });

    it('returns pagination metadata', async () => {
      prisma.user.findMany.mockResolvedValue([{ id: 'u1' }]);
      prisma.user.count.mockResolvedValue(41);

      const res = await service.findAll({ page: 2, limit: 20 });

      expect(res.meta).toEqual({
        page: 2,
        limit: 20,
        total: 41,
        totalPages: 3,
      });
      expect(prisma.user.findMany.mock.calls[0][0].skip).toBe(20);
    });
  });

  describe('findOne', () => {
    it('404s for an unknown user', async () => {
      prisma.user.findUnique.mockResolvedValue(null);

      await expect(service.findOne('nope')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('returns the user with counts and recent orders', async () => {
      const user = { id: 'u1', _count: { orders: 3, reviews: 1 }, orders: [] };
      prisma.user.findUnique.mockResolvedValue(user);

      const res = await service.findOne('u1');

      expect(res).toBe(user);
      const args = prisma.user.findUnique.mock.calls[0][0];
      expect(args.select.passwordHash).toBeUndefined();
      expect(args.select.orders.take).toBe(5);
    });
  });

  describe('updateRole', () => {
    it('404s for an unknown user', async () => {
      prisma.user.findUnique.mockResolvedValue(null);

      await expect(
        service.updateRole('nope', Role.ADMIN, 'admin1'),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(prisma.user.update).not.toHaveBeenCalled();
    });

    it('forbids an admin from demoting themselves', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 'admin1', role: 'ADMIN' });

      await expect(
        service.updateRole('admin1', Role.CUSTOMER, 'admin1'),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(prisma.user.update).not.toHaveBeenCalled();
    });

    it('lets an admin keep their own admin role (idempotent self-update)', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 'admin1', role: 'ADMIN' });
      prisma.user.update.mockResolvedValue({ id: 'admin1', role: 'ADMIN' });

      await service.updateRole('admin1', Role.ADMIN, 'admin1');

      expect(prisma.user.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'admin1' },
          data: { role: Role.ADMIN },
        }),
      );
    });

    it('promotes another user and never returns the password hash', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 'u2', role: 'CUSTOMER' });
      prisma.user.update.mockResolvedValue({ id: 'u2', role: 'ADMIN' });

      await service.updateRole('u2', Role.ADMIN, 'admin1');

      const args = prisma.user.update.mock.calls[0][0];
      expect(args.data).toEqual({ role: Role.ADMIN });
      expect(args.select.passwordHash).toBeUndefined();
    });
  });
});
