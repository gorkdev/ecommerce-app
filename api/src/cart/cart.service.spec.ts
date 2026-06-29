import { Test } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { CartService } from './cart.service';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '../generated/prisma/client';

type PrismaMock = {
  cart: { upsert: jest.Mock };
  cartItem: {
    findUnique: jest.Mock;
    upsert: jest.Mock;
    update: jest.Mock;
    delete: jest.Mock;
    deleteMany: jest.Mock;
  };
  product: { findUnique: jest.Mock };
};

const activeProduct = (over: Partial<Record<string, unknown>> = {}) => ({
  id: 'p1',
  isActive: true,
  stock: 10,
  price: new Prisma.Decimal('5.00'),
  currency: 'TRY',
  ...over,
});

describe('CartService', () => {
  let service: CartService;
  let prisma: PrismaMock;

  beforeEach(async () => {
    prisma = {
      cart: { upsert: jest.fn() },
      cartItem: {
        findUnique: jest.fn(),
        upsert: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
        deleteMany: jest.fn(),
      },
      product: { findUnique: jest.fn() },
    };

    const moduleRef = await Test.createTestingModule({
      providers: [CartService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    service = moduleRef.get(CartService);
  });

  describe('getCart', () => {
    it('lazily creates the cart and computes subtotal + item count', async () => {
      prisma.cart.upsert.mockResolvedValue({
        id: 'cart1',
        items: [
          { quantity: 2, product: { price: new Prisma.Decimal('5.00'), currency: 'TRY' } },
          { quantity: 1, product: { price: new Prisma.Decimal('10.50'), currency: 'TRY' } },
        ],
      });

      const res = await service.getCart('u1');

      expect(res.summary).toEqual({
        itemCount: 3,
        subtotal: '20.50',
        currency: 'TRY',
      });
    });

    it('reports a zero subtotal for an empty cart', async () => {
      prisma.cart.upsert.mockResolvedValue({ id: 'cart1', items: [] });

      const res = await service.getCart('u1');

      expect(res.summary).toEqual({
        itemCount: 0,
        subtotal: '0.00',
        currency: 'TRY',
      });
    });
  });

  describe('addItem', () => {
    it('rejects a missing or inactive product', async () => {
      prisma.product.findUnique.mockResolvedValue(null);

      await expect(
        service.addItem('u1', { productId: 'nope', quantity: 1 }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('accumulates quantity onto an existing line', async () => {
      prisma.product.findUnique.mockResolvedValue(activeProduct());
      prisma.cart.upsert.mockResolvedValue({ id: 'cart1', items: [] });
      prisma.cartItem.findUnique.mockResolvedValue({ quantity: 2 });
      prisma.cartItem.upsert.mockResolvedValue({});

      await service.addItem('u1', { productId: 'p1', quantity: 3 });

      expect(prisma.cartItem.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { cartId_productId: { cartId: 'cart1', productId: 'p1' } },
          create: expect.objectContaining({ quantity: 5 }),
          update: { quantity: 5 },
        }),
      );
    });

    it('rejects when the accumulated quantity exceeds stock', async () => {
      prisma.product.findUnique.mockResolvedValue(activeProduct({ stock: 10 }));
      prisma.cart.upsert.mockResolvedValue({ id: 'cart1', items: [] });
      prisma.cartItem.findUnique.mockResolvedValue({ quantity: 2 });

      await expect(
        service.addItem('u1', { productId: 'p1', quantity: 9 }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(prisma.cartItem.upsert).not.toHaveBeenCalled();
    });
  });

  describe('updateItem', () => {
    it('throws when the cart item does not exist', async () => {
      prisma.cart.upsert.mockResolvedValue({ id: 'cart1' });
      prisma.cartItem.findUnique.mockResolvedValue(null);

      await expect(
        service.updateItem('u1', 'p1', { quantity: 1 }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('rejects a quantity above available stock', async () => {
      prisma.cart.upsert.mockResolvedValue({ id: 'cart1' });
      prisma.cartItem.findUnique.mockResolvedValue({ quantity: 1 });
      prisma.product.findUnique.mockResolvedValue(activeProduct({ stock: 3 }));

      await expect(
        service.updateItem('u1', 'p1', { quantity: 4 }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(prisma.cartItem.update).not.toHaveBeenCalled();
    });
  });

  describe('removeItem', () => {
    it('throws when the cart item does not exist', async () => {
      prisma.cart.upsert.mockResolvedValue({ id: 'cart1' });
      prisma.cartItem.findUnique.mockResolvedValue(null);

      await expect(service.removeItem('u1', 'p1')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(prisma.cartItem.delete).not.toHaveBeenCalled();
    });
  });
});
