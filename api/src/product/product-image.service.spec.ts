import { Test } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { ProductImageService } from './product-image.service';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';

type PrismaMock = {
  product: { findUnique: jest.Mock };
  productImage: {
    create: jest.Mock;
    findUnique: jest.Mock;
    delete: jest.Mock;
  };
};

describe('ProductImageService', () => {
  let service: ProductImageService;
  let prisma: PrismaMock;
  let storage: {
    buildKey: jest.Mock;
    createPresignedUpload: jest.Mock;
    publicUrl: jest.Mock;
    keyFromUrl: jest.Mock;
    deleteObject: jest.Mock;
  };

  beforeEach(async () => {
    prisma = {
      product: { findUnique: jest.fn() },
      productImage: {
        create: jest.fn(),
        findUnique: jest.fn(),
        delete: jest.fn(),
      },
    };
    storage = {
      buildKey: jest.fn(() => 'products/p1/uuid.png'),
      createPresignedUpload: jest.fn().mockResolvedValue('http://signed'),
      publicUrl: jest.fn((k: string) => `http://host/product-images/${k}`),
      keyFromUrl: jest.fn(() => 'products/p1/uuid.png'),
      deleteObject: jest.fn().mockResolvedValue(undefined),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        ProductImageService,
        { provide: PrismaService, useValue: prisma },
        { provide: StorageService, useValue: storage },
      ],
    }).compile();

    service = moduleRef.get(ProductImageService);
  });

  describe('createUploadUrl', () => {
    it('returns key + upload URL + public URL for an existing product', async () => {
      prisma.product.findUnique.mockResolvedValue({ id: 'p1' });

      const res = await service.createUploadUrl('p1', {
        contentType: 'image/png',
      });

      expect(res.key).toBe('products/p1/uuid.png');
      expect(res.uploadUrl).toBe('http://signed');
      expect(res.publicUrl).toContain('products/p1/uuid.png');
    });

    it('throws for an unknown product', async () => {
      prisma.product.findUnique.mockResolvedValue(null);

      await expect(
        service.createUploadUrl('missing', { contentType: 'image/png' }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('attach', () => {
    it('rejects a key outside the product namespace', async () => {
      prisma.product.findUnique.mockResolvedValue({ id: 'p1' });

      await expect(
        service.attach('p1', { key: 'products/other/x.png' }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(prisma.productImage.create).not.toHaveBeenCalled();
    });

    it('persists the image with its public URL', async () => {
      prisma.product.findUnique.mockResolvedValue({ id: 'p1' });
      prisma.productImage.create.mockResolvedValue({ id: 'img1' });

      await service.attach('p1', { key: 'products/p1/uuid.png', sortOrder: 2 });

      expect(prisma.productImage.create).toHaveBeenCalledWith({
        data: {
          productId: 'p1',
          url: 'http://host/product-images/products/p1/uuid.png',
          sortOrder: 2,
        },
      });
    });
  });

  describe('remove', () => {
    it('throws when the image belongs to another product', async () => {
      prisma.productImage.findUnique.mockResolvedValue({
        id: 'img1',
        productId: 'other',
        url: 'http://host/product-images/products/other/x.png',
      });

      await expect(service.remove('p1', 'img1')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(storage.deleteObject).not.toHaveBeenCalled();
    });

    it('deletes from storage and the database', async () => {
      prisma.productImage.findUnique.mockResolvedValue({
        id: 'img1',
        productId: 'p1',
        url: 'http://host/product-images/products/p1/uuid.png',
      });
      prisma.productImage.delete.mockResolvedValue({ id: 'img1' });

      await service.remove('p1', 'img1');

      expect(storage.deleteObject).toHaveBeenCalledWith('products/p1/uuid.png');
      expect(prisma.productImage.delete).toHaveBeenCalledWith({
        where: { id: 'img1' },
      });
    });
  });
});
