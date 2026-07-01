import { Test } from '@nestjs/testing';
import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { ReviewService } from './review.service';
import { PrismaService } from '../prisma/prisma.service';

type PrismaMock = {
  review: {
    findMany: jest.Mock;
    findUnique: jest.Mock;
    upsert: jest.Mock;
    delete: jest.Mock;
    groupBy: jest.Mock;
    count: jest.Mock;
  };
  product: { findUnique: jest.Mock };
  orderItem: { count: jest.Mock };
  $transaction: jest.Mock;
};

describe('ReviewService', () => {
  let service: ReviewService;
  let prisma: PrismaMock;

  beforeEach(async () => {
    prisma = {
      review: {
        findMany: jest.fn().mockResolvedValue([]),
        findUnique: jest.fn(),
        upsert: jest.fn(),
        delete: jest.fn(),
        groupBy: jest.fn().mockResolvedValue([]),
        count: jest.fn().mockResolvedValue(0),
      },
      product: { findUnique: jest.fn() },
      orderItem: { count: jest.fn() },
      // Support the array form used by the admin paged listing.
      $transaction: jest.fn((arg) =>
        Array.isArray(arg) ? Promise.all(arg) : arg(prisma),
      ),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [ReviewService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    service = moduleRef.get(ReviewService);
  });

  describe('listForProduct', () => {
    it('404s for a missing product', async () => {
      prisma.product.findUnique.mockResolvedValue(null);

      await expect(service.listForProduct('nope')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('aggregates a rating summary from grouped counts', async () => {
      prisma.product.findUnique.mockResolvedValue({ id: 'p1' });
      prisma.review.findMany.mockResolvedValue([{ id: 'r1' }]);
      prisma.review.groupBy.mockResolvedValue([
        { rating: 5, _count: { _all: 2 } },
        { rating: 3, _count: { _all: 1 } },
      ]);

      const { summary } = await service.listForProduct('p1');

      // (5*2 + 3*1) / 3 = 4.333 -> rounded to one decimal.
      expect(summary.average).toBe(4.3);
      expect(summary.count).toBe(3);
      expect(summary.distribution).toEqual({ 1: 0, 2: 0, 3: 1, 4: 0, 5: 2 });
    });

    it('reports a zero summary when there are no reviews', async () => {
      prisma.product.findUnique.mockResolvedValue({ id: 'p1' });

      const { summary } = await service.listForProduct('p1');

      expect(summary).toEqual({
        average: 0,
        count: 0,
        distribution: { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 },
      });
    });
  });

  describe('submit', () => {
    it('404s for a missing product', async () => {
      prisma.product.findUnique.mockResolvedValue(null);

      await expect(
        service.submit('u1', 'nope', { rating: 5 }),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(prisma.review.upsert).not.toHaveBeenCalled();
    });

    it('forbids a customer who has not purchased the product', async () => {
      prisma.product.findUnique.mockResolvedValue({ id: 'p1' });
      prisma.orderItem.count.mockResolvedValue(0);

      await expect(
        service.submit('u1', 'p1', { rating: 5 }),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(prisma.review.upsert).not.toHaveBeenCalled();
    });

    it('upserts the review for a verified buyer', async () => {
      prisma.product.findUnique.mockResolvedValue({ id: 'p1' });
      prisma.orderItem.count.mockResolvedValue(1);
      prisma.review.upsert.mockResolvedValue({ id: 'r1' });

      await service.submit('u1', 'p1', { rating: 4, comment: 'Solid' });

      expect(prisma.review.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { productId_userId: { productId: 'p1', userId: 'u1' } },
          create: {
            productId: 'p1',
            userId: 'u1',
            rating: 4,
            comment: 'Solid',
          },
          update: { rating: 4, comment: 'Solid' },
        }),
      );
    });

    it('only counts paid-or-later orders as a purchase', async () => {
      prisma.product.findUnique.mockResolvedValue({ id: 'p1' });
      prisma.orderItem.count.mockResolvedValue(1);
      prisma.review.upsert.mockResolvedValue({ id: 'r1' });

      await service.submit('u1', 'p1', { rating: 5 });

      const where = prisma.orderItem.count.mock.calls[0][0].where;
      expect(where.productId).toBe('p1');
      expect(where.order.userId).toBe('u1');
      expect(where.order.status.in).toEqual([
        'PAID',
        'PREPARING',
        'SHIPPED',
        'DELIVERED',
      ]);
    });
  });

  describe('removeOwn', () => {
    it('throws when the caller has no review', async () => {
      prisma.review.findUnique.mockResolvedValue(null);

      await expect(service.removeOwn('u1', 'p1')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(prisma.review.delete).not.toHaveBeenCalled();
    });

    it('deletes the caller own review', async () => {
      prisma.review.findUnique.mockResolvedValue({ id: 'r1' });
      prisma.review.delete.mockResolvedValue({});

      await service.removeOwn('u1', 'p1');

      expect(prisma.review.delete).toHaveBeenCalledWith({
        where: { productId_userId: { productId: 'p1', userId: 'u1' } },
      });
    });
  });

  describe('admin remove', () => {
    it('404s for an unknown review id', async () => {
      prisma.review.findUnique.mockResolvedValue(null);

      await expect(service.remove('nope')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(prisma.review.delete).not.toHaveBeenCalled();
    });

    it('deletes any review by id', async () => {
      prisma.review.findUnique.mockResolvedValue({ id: 'r1' });
      prisma.review.delete.mockResolvedValue({});

      await service.remove('r1');

      expect(prisma.review.delete).toHaveBeenCalledWith({
        where: { id: 'r1' },
      });
    });
  });
});
