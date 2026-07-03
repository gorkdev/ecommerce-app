import { Test } from '@nestjs/testing';
import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { CouponService } from './coupon.service';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma, CouponType, Coupon } from '../generated/prisma/client';

type PrismaMock = {
  coupon: {
    findUnique: jest.Mock;
    findMany: jest.Mock;
    create: jest.Mock;
    update: jest.Mock;
    delete: jest.Mock;
    count: jest.Mock;
  };
  order: { count: jest.Mock };
  cart: { findUnique: jest.Mock };
  $transaction: jest.Mock;
};

// A fully-formed, valid coupon; individual tests override the fields they probe.
const coupon = (over: Partial<Coupon> = {}): Coupon =>
  ({
    id: 'c1',
    code: 'SAVE10',
    type: CouponType.PERCENTAGE,
    value: new Prisma.Decimal('10'),
    minSubtotal: new Prisma.Decimal('0'),
    maxUses: null,
    usedCount: 0,
    expiresAt: null,
    isActive: true,
    createdAt: new Date('2026-01-01T00:00:00Z'),
    ...over,
  }) as Coupon;

const now = new Date('2026-07-03T00:00:00Z');
const D = (v: string | number) => new Prisma.Decimal(v);

describe('CouponService', () => {
  let service: CouponService;
  let prisma: PrismaMock;

  beforeEach(async () => {
    prisma = {
      coupon: {
        findUnique: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
        create: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
        count: jest.fn().mockResolvedValue(0),
      },
      order: { count: jest.fn().mockResolvedValue(0) },
      cart: { findUnique: jest.fn() },
      $transaction: jest.fn((arg) =>
        Array.isArray(arg) ? Promise.all(arg) : arg(prisma),
      ),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [CouponService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    service = moduleRef.get(CouponService);
  });

  describe('price', () => {
    it('applies a percentage discount', () => {
      const { discount, total } = service.price(coupon({ value: D('10') }), D('200'));
      expect(discount.toFixed(2)).toBe('20.00');
      expect(total.toFixed(2)).toBe('180.00');
    });

    it('applies a fixed discount', () => {
      const { discount, total } = service.price(
        coupon({ type: CouponType.FIXED, value: D('30') }),
        D('200'),
      );
      expect(discount.toFixed(2)).toBe('30.00');
      expect(total.toFixed(2)).toBe('170.00');
    });

    it('never discounts below zero', () => {
      const { discount, total } = service.price(
        coupon({ type: CouponType.FIXED, value: D('500') }),
        D('200'),
      );
      expect(discount.toFixed(2)).toBe('200.00');
      expect(total.toFixed(2)).toBe('0.00');
    });
  });

  describe('assertUsable', () => {
    it('passes for a valid coupon', () => {
      expect(() => service.assertUsable(coupon(), D('100'), now)).not.toThrow();
    });

    it('rejects an inactive coupon', () => {
      expect(() =>
        service.assertUsable(coupon({ isActive: false }), D('100'), now),
      ).toThrow(BadRequestException);
    });

    it('rejects an expired coupon', () => {
      expect(() =>
        service.assertUsable(
          coupon({ expiresAt: new Date('2020-01-01T00:00:00Z') }),
          D('100'),
          now,
        ),
      ).toThrow(BadRequestException);
    });

    it('rejects a coupon that hit its usage cap', () => {
      expect(() =>
        service.assertUsable(
          coupon({ maxUses: 5, usedCount: 5 }),
          D('100'),
          now,
        ),
      ).toThrow(BadRequestException);
    });

    it('rejects a subtotal below the minimum', () => {
      expect(() =>
        service.assertUsable(
          coupon({ minSubtotal: D('500') }),
          D('100'),
          now,
        ),
      ).toThrow(BadRequestException);
    });
  });

  describe('resolve', () => {
    it('404s for an unknown code', async () => {
      prisma.coupon.findUnique.mockResolvedValue(null);
      await expect(service.resolve('NOPE', D('100'), now)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('normalizes the code and returns the priced discount', async () => {
      prisma.coupon.findUnique.mockResolvedValue(coupon());
      const res = await service.resolve('save10', D('200'), now);

      expect(prisma.coupon.findUnique).toHaveBeenCalledWith({
        where: { code: 'SAVE10' },
      });
      expect(res.discount.toFixed(2)).toBe('20.00');
      expect(res.total.toFixed(2)).toBe('180.00');
    });
  });

  describe('create', () => {
    it('uppercases the code and defaults optional fields', async () => {
      prisma.coupon.findUnique.mockResolvedValue(null);
      prisma.coupon.create.mockResolvedValue(coupon());

      await service.create({ code: 'save10', type: CouponType.PERCENTAGE, value: 10 });

      expect(prisma.coupon.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            code: 'SAVE10',
            minSubtotal: 0,
            maxUses: null,
            expiresAt: null,
            isActive: true,
          }),
        }),
      );
    });

    it('rejects a percentage over 100', async () => {
      prisma.coupon.findUnique.mockResolvedValue(null);
      await expect(
        service.create({ code: 'BIG', type: CouponType.PERCENTAGE, value: 150 }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(prisma.coupon.create).not.toHaveBeenCalled();
    });

    it('rejects a duplicate code', async () => {
      prisma.coupon.findUnique.mockResolvedValue(coupon());
      await expect(
        service.create({ code: 'SAVE10', type: CouponType.FIXED, value: 5 }),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(prisma.coupon.create).not.toHaveBeenCalled();
    });
  });

  describe('remove', () => {
    it('blocks deleting a coupon already used by orders', async () => {
      prisma.coupon.findUnique.mockResolvedValue(coupon());
      prisma.order.count.mockResolvedValue(2);

      await expect(service.remove('c1')).rejects.toBeInstanceOf(
        ConflictException,
      );
      expect(prisma.coupon.delete).not.toHaveBeenCalled();
    });

    it('deletes an unused coupon', async () => {
      prisma.coupon.findUnique.mockResolvedValue(coupon());
      prisma.order.count.mockResolvedValue(0);
      prisma.coupon.delete.mockResolvedValue({});

      await service.remove('c1');

      expect(prisma.coupon.delete).toHaveBeenCalledWith({ where: { id: 'c1' } });
    });
  });
});
