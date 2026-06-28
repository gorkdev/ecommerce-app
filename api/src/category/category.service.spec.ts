import { Test } from '@nestjs/testing';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { CategoryService } from './category.service';
import { PrismaService } from '../prisma/prisma.service';

type PrismaMock = {
  category: {
    create: jest.Mock;
    findUnique: jest.Mock;
    findMany: jest.Mock;
    update: jest.Mock;
    delete: jest.Mock;
  };
  product: { count: jest.Mock };
};

describe('CategoryService', () => {
  let service: CategoryService;
  let prisma: PrismaMock;

  beforeEach(async () => {
    prisma = {
      category: {
        create: jest.fn(),
        findUnique: jest.fn(),
        findMany: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
      product: { count: jest.fn() },
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        CategoryService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = moduleRef.get(CategoryService);
  });

  describe('create', () => {
    it('derives a slug from the name and persists the category', async () => {
      prisma.category.findUnique.mockResolvedValue(null);
      prisma.category.create.mockResolvedValue({ id: 'c1' });

      await service.create({ name: 'Spor Ayakkabı' });

      expect(prisma.category.create).toHaveBeenCalledWith({
        data: { name: 'Spor Ayakkabı', slug: 'spor-ayakkabi', parentId: null },
      });
    });

    it('rejects a duplicate slug', async () => {
      prisma.category.findUnique.mockResolvedValue({ id: 'other' });

      await expect(service.create({ name: 'Shoes' })).rejects.toBeInstanceOf(
        ConflictException,
      );
      expect(prisma.category.create).not.toHaveBeenCalled();
    });

    it('rejects an unknown parentId', async () => {
      // slug check passes, parent lookup fails
      prisma.category.findUnique
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(null);

      await expect(
        service.create({ name: 'Sneakers', parentId: 'missing' }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('findTree', () => {
    it('nests children under their parents and returns roots only', async () => {
      prisma.category.findMany.mockResolvedValue([
        { id: 'root', slug: 'root', name: 'Root', parentId: null },
        { id: 'child', slug: 'child', name: 'Child', parentId: 'root' },
      ]);

      const tree = await service.findTree();

      expect(tree).toHaveLength(1);
      expect(tree[0].id).toBe('root');
      expect(tree[0].children).toHaveLength(1);
      expect(tree[0].children[0].id).toBe('child');
    });
  });

  describe('findBySlug', () => {
    it('throws when the category does not exist', async () => {
      prisma.category.findUnique.mockResolvedValue(null);

      await expect(service.findBySlug('nope')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('update', () => {
    it('refuses to make a category its own parent', async () => {
      prisma.category.findUnique.mockResolvedValue({ id: 'c1' });

      await expect(
        service.update('c1', { parentId: 'c1' }),
      ).rejects.toBeInstanceOf(ConflictException);
    });
  });

  describe('remove', () => {
    it('refuses to delete a category that still has products', async () => {
      prisma.category.findUnique.mockResolvedValue({ id: 'c1' });
      prisma.product.count.mockResolvedValue(3);

      await expect(service.remove('c1')).rejects.toBeInstanceOf(
        ConflictException,
      );
      expect(prisma.category.delete).not.toHaveBeenCalled();
    });

    it('deletes an empty category', async () => {
      prisma.category.findUnique.mockResolvedValue({ id: 'c1' });
      prisma.product.count.mockResolvedValue(0);
      prisma.category.delete.mockResolvedValue({ id: 'c1' });

      await service.remove('c1');

      expect(prisma.category.delete).toHaveBeenCalledWith({
        where: { id: 'c1' },
      });
    });
  });
});
