import { Test } from '@nestjs/testing';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { ProductService } from './product.service';
import { PrismaService } from '../prisma/prisma.service';

type PrismaMock = {
  product: {
    create: jest.Mock;
    findUnique: jest.Mock;
    findMany: jest.Mock;
    count: jest.Mock;
    update: jest.Mock;
    delete: jest.Mock;
  };
  category: { findUnique: jest.Mock };
  $transaction: jest.Mock;
};

describe('ProductService', () => {
  let service: ProductService;
  let prisma: PrismaMock;

  beforeEach(async () => {
    prisma = {
      product: {
        create: jest.fn(),
        findUnique: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
      category: { findUnique: jest.fn() },
      // Mirror Prisma's $transaction([...]) array form used by findAll.
      $transaction: jest.fn((ops: Promise<unknown>[]) => Promise.all(ops)),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        ProductService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = moduleRef.get(ProductService);
  });

  describe('create', () => {
    it('derives a slug, defaults fields, and persists', async () => {
      prisma.product.findUnique.mockResolvedValue(null);
      prisma.category.findUnique.mockResolvedValue({ id: 'cat1' });
      prisma.product.create.mockResolvedValue({ id: 'p1' });

      await service.create({
        name: 'Running Shoes',
        description: 'Fast',
        price: 49.9,
        categoryId: 'cat1',
      });

      expect(prisma.product.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            slug: 'running-shoes',
            currency: 'TRY',
            stock: 0,
            isActive: true,
            categoryId: 'cat1',
          }),
        }),
      );
    });

    it('rejects a duplicate slug', async () => {
      prisma.product.findUnique.mockResolvedValue({ id: 'other' });

      await expect(
        service.create({
          name: 'Shoes',
          description: 'x',
          price: 10,
          categoryId: 'cat1',
        }),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('rejects an unknown category', async () => {
      prisma.product.findUnique.mockResolvedValue(null);
      prisma.category.findUnique.mockResolvedValue(null);

      await expect(
        service.create({
          name: 'Shoes',
          description: 'x',
          price: 10,
          categoryId: 'missing',
        }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('findAll', () => {
    it('filters active products, applies price range + sort, returns paged meta', async () => {
      prisma.product.findMany.mockResolvedValue([{ id: 'p1' }]);
      prisma.product.count.mockResolvedValue(1);

      const result = await service.findAll({
        page: 2,
        limit: 10,
        search: 'shoe',
        minPrice: 5,
        maxPrice: 50,
        sort: 'price_asc',
      });

      const findArgs = prisma.product.findMany.mock.calls[0][0];
      expect(findArgs.where).toEqual({
        isActive: true,
        name: { contains: 'shoe', mode: 'insensitive' },
        price: { gte: 5, lte: 50 },
      });
      expect(findArgs.orderBy).toEqual({ price: 'asc' });
      expect(findArgs.skip).toBe(10);
      expect(findArgs.take).toBe(10);
      expect(result.meta).toEqual({
        page: 2,
        limit: 10,
        total: 1,
        totalPages: 1,
      });
    });

    it('defaults to newest sort and page 1', async () => {
      prisma.product.findMany.mockResolvedValue([]);
      prisma.product.count.mockResolvedValue(0);

      await service.findAll({});

      const findArgs = prisma.product.findMany.mock.calls[0][0];
      expect(findArgs.orderBy).toEqual({ createdAt: 'desc' });
      expect(findArgs.skip).toBe(0);
    });
  });

  describe('findBySlug', () => {
    it('throws when missing', async () => {
      prisma.product.findUnique.mockResolvedValue(null);

      await expect(service.findBySlug('nope')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('remove', () => {
    it('throws when the product does not exist', async () => {
      prisma.product.findUnique.mockResolvedValue(null);

      await expect(service.remove('nope')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(prisma.product.delete).not.toHaveBeenCalled();
    });
  });
});
