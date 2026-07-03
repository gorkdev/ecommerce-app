import { Test } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { OrderService } from './order.service';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentService } from '../payment/payment.service';
import { CouponService } from '../coupon/coupon.service';
import { Prisma, OrderStatus } from '../generated/prisma/client';

type PrismaMock = {
  cart: { findUnique: jest.Mock };
  order: {
    create: jest.Mock;
    findUnique: jest.Mock;
    findFirst: jest.Mock;
    findMany: jest.Mock;
    count: jest.Mock;
    update: jest.Mock;
  };
  product: { updateMany: jest.Mock; update: jest.Mock };
  cartItem: { deleteMany: jest.Mock };
  coupon: { updateMany: jest.Mock };
  address: { findFirst: jest.Mock };
  $transaction: jest.Mock;
};

const cartLine = (over: Partial<Record<string, unknown>> = {}) => ({
  productId: 'p1',
  quantity: 2,
  product: {
    id: 'p1',
    name: 'Widget',
    isActive: true,
    stock: 5,
    price: new Prisma.Decimal('25.00'),
    currency: 'TRY',
  },
  ...over,
});

describe('OrderService', () => {
  let service: OrderService;
  let prisma: PrismaMock;
  let payment: { createPaymentIntent: jest.Mock };
  let coupons: { resolve: jest.Mock };

  beforeEach(async () => {
    prisma = {
      cart: { findUnique: jest.fn() },
      order: {
        create: jest.fn(),
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
        update: jest.fn(),
      },
      product: { updateMany: jest.fn(), update: jest.fn() },
      cartItem: { deleteMany: jest.fn() },
      coupon: { updateMany: jest.fn() },
      address: { findFirst: jest.fn() },
      // Support both the array form (findAll) and the callback form (checkout).
      $transaction: jest.fn((arg: unknown) =>
        Array.isArray(arg)
          ? Promise.all(arg as Promise<unknown>[])
          : (arg as (tx: PrismaMock) => unknown)(prisma),
      ),
    };
    payment = {
      createPaymentIntent: jest.fn().mockResolvedValue({
        id: 'pi_123',
        client_secret: 'secret_123',
      }),
    };
    // These order tests never pass a coupon code, so a bare stub suffices;
    // coupon pricing/redemption is covered in coupon.service + the e2e flow.
    coupons = { resolve: jest.fn() };

    const moduleRef = await Test.createTestingModule({
      providers: [
        OrderService,
        { provide: PrismaService, useValue: prisma },
        { provide: PaymentService, useValue: payment },
        { provide: CouponService, useValue: coupons },
      ],
    }).compile();

    service = moduleRef.get(OrderService);
  });

  describe('checkout', () => {
    it('rejects an empty cart', async () => {
      prisma.cart.findUnique.mockResolvedValue({ id: 'c1', items: [] });

      await expect(service.checkout('u1', {})).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('reserves stock, creates the order, clears the cart, opens an intent', async () => {
      prisma.cart.findUnique.mockResolvedValue({
        id: 'c1',
        items: [cartLine()],
      });
      prisma.product.updateMany.mockResolvedValue({ count: 1 });
      prisma.order.create.mockResolvedValue({ id: 'o1', items: [] });
      prisma.cartItem.deleteMany.mockResolvedValue({ count: 1 });
      prisma.order.update.mockResolvedValue({});

      const result = await service.checkout('u1', {});

      // Conditional decrement protects against overselling.
      expect(prisma.product.updateMany).toHaveBeenCalledWith({
        where: { id: 'p1', stock: { gte: 2 } },
        data: { stock: { decrement: 2 } },
      });
      // Totals: 25.00 * 2 = 50.00 -> 5000 minor units.
      expect(payment.createPaymentIntent).toHaveBeenCalledWith(
        expect.objectContaining({ amountMinor: 5000, currency: 'TRY', orderId: 'o1' }),
      );
      expect(prisma.cartItem.deleteMany).toHaveBeenCalledWith({
        where: { cartId: 'c1' },
      });
      expect(prisma.order.update).toHaveBeenCalledWith({
        where: { id: 'o1' },
        data: { stripePaymentIntentId: 'pi_123' },
      });
      expect(result.clientSecret).toBe('secret_123');
    });

    it('aborts when a concurrent decrement leaves no stock', async () => {
      prisma.cart.findUnique.mockResolvedValue({
        id: 'c1',
        items: [cartLine()],
      });
      prisma.product.updateMany.mockResolvedValue({ count: 0 });

      await expect(service.checkout('u1', {})).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(payment.createPaymentIntent).not.toHaveBeenCalled();
    });

    it('rejects a line whose quantity exceeds stock up front', async () => {
      prisma.cart.findUnique.mockResolvedValue({
        id: 'c1',
        items: [cartLine({ quantity: 99 })],
      });

      await expect(service.checkout('u1', {})).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('rejects an address that is not the user\'s', async () => {
      prisma.cart.findUnique.mockResolvedValue({
        id: 'c1',
        items: [cartLine()],
      });
      prisma.address.findFirst.mockResolvedValue(null);

      await expect(
        service.checkout('u1', { addressId: 'addr-x' }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('markPaid', () => {
    it('flips a pending order to PAID', async () => {
      prisma.order.findUnique.mockResolvedValue({
        id: 'o1',
        status: OrderStatus.PENDING,
      });

      await service.markPaid('pi_123');

      expect(prisma.order.update).toHaveBeenCalledWith({
        where: { id: 'o1' },
        data: { status: OrderStatus.PAID },
      });
    });

    it('is a no-op for an already-paid order', async () => {
      prisma.order.findUnique.mockResolvedValue({
        id: 'o1',
        status: OrderStatus.PAID,
      });

      await service.markPaid('pi_123');

      expect(prisma.order.update).not.toHaveBeenCalled();
    });

    it('ignores an unknown payment intent', async () => {
      prisma.order.findUnique.mockResolvedValue(null);

      await service.markPaid('pi_unknown');

      expect(prisma.order.update).not.toHaveBeenCalled();
    });
  });

  describe('markPaymentFailed', () => {
    it('cancels the order and restocks its items', async () => {
      prisma.order.findUnique.mockResolvedValue({
        id: 'o1',
        status: OrderStatus.PENDING,
        items: [{ productId: 'p1', quantity: 2 }],
      });

      await service.markPaymentFailed('pi_123');

      expect(prisma.product.update).toHaveBeenCalledWith({
        where: { id: 'p1' },
        data: { stock: { increment: 2 } },
      });
      expect(prisma.order.update).toHaveBeenCalledWith({
        where: { id: 'o1' },
        data: { status: OrderStatus.CANCELLED },
      });
    });
  });

  describe('updateStatus', () => {
    it('throws when the order does not exist', async () => {
      prisma.order.findUnique.mockResolvedValue(null);

      await expect(
        service.updateStatus('nope', OrderStatus.PREPARING),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('rejects an illegal transition', async () => {
      prisma.order.findUnique.mockResolvedValue({
        id: 'o1',
        status: OrderStatus.PREPARING,
      });

      await expect(
        service.updateStatus('o1', OrderStatus.DELIVERED),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('allows a legal transition', async () => {
      prisma.order.findUnique.mockResolvedValue({
        id: 'o1',
        status: OrderStatus.PAID,
      });
      prisma.order.update.mockResolvedValue({ id: 'o1' });

      await service.updateStatus('o1', OrderStatus.PREPARING);

      expect(prisma.order.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'o1' },
          data: { status: OrderStatus.PREPARING },
        }),
      );
    });
  });
});
