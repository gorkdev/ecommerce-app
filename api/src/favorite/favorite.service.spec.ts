import { Test } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { FavoriteService } from './favorite.service';
import { PrismaService } from '../prisma/prisma.service';

type PrismaMock = {
  favorite: {
    findMany: jest.Mock;
    findUnique: jest.Mock;
    upsert: jest.Mock;
    delete: jest.Mock;
  };
  product: { findUnique: jest.Mock };
};

describe('FavoriteService', () => {
  let service: FavoriteService;
  let prisma: PrismaMock;

  beforeEach(async () => {
    prisma = {
      favorite: {
        findMany: jest.fn().mockResolvedValue([]),
        findUnique: jest.fn(),
        upsert: jest.fn(),
        delete: jest.fn(),
      },
      product: { findUnique: jest.fn() },
    };

    const moduleRef = await Test.createTestingModule({
      providers: [FavoriteService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    service = moduleRef.get(FavoriteService);
  });

  describe('add', () => {
    it('rejects a missing or inactive product', async () => {
      prisma.product.findUnique.mockResolvedValue(null);

      await expect(service.add('u1', 'nope')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(prisma.favorite.upsert).not.toHaveBeenCalled();
    });

    it('upserts idempotently and returns the updated list', async () => {
      prisma.product.findUnique.mockResolvedValue({ id: 'p1', isActive: true });
      prisma.favorite.upsert.mockResolvedValue({});

      await service.add('u1', 'p1');

      expect(prisma.favorite.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { userId_productId: { userId: 'u1', productId: 'p1' } },
          create: { userId: 'u1', productId: 'p1' },
          update: {},
        }),
      );
      expect(prisma.favorite.findMany).toHaveBeenCalled();
    });
  });

  describe('remove', () => {
    it('throws when the favorite does not exist', async () => {
      prisma.favorite.findUnique.mockResolvedValue(null);

      await expect(service.remove('u1', 'p1')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(prisma.favorite.delete).not.toHaveBeenCalled();
    });

    it('deletes an existing favorite', async () => {
      prisma.favorite.findUnique.mockResolvedValue({ id: 'f1' });
      prisma.favorite.delete.mockResolvedValue({});

      await service.remove('u1', 'p1');

      expect(prisma.favorite.delete).toHaveBeenCalledWith({
        where: { userId_productId: { userId: 'u1', productId: 'p1' } },
      });
    });
  });
});
