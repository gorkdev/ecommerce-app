import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma, CouponType, Coupon } from '../generated/prisma/client';
import { CreateCouponDto } from './dto/create-coupon.dto';
import { UpdateCouponDto } from './dto/update-coupon.dto';
import { QueryCouponDto } from './dto/query-coupon.dto';

const MAX_PAGE_SIZE = 100;

export interface AppliedCoupon {
  coupon: Coupon;
  discount: Prisma.Decimal;
  total: Prisma.Decimal;
}

@Injectable()
export class CouponService {
  constructor(private readonly prisma: PrismaService) {}

  // ---- Admin CRUD ----

  async create(dto: CreateCouponDto) {
    const code = this.normalize(dto.code);
    await this.ensureCodeFree(code);
    this.assertValueForType(dto.type, dto.value);
    return this.prisma.coupon.create({
      data: {
        code,
        type: dto.type,
        value: dto.value,
        minSubtotal: dto.minSubtotal ?? 0,
        maxUses: dto.maxUses ?? null,
        expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : null,
        isActive: dto.isActive ?? true,
      },
    });
  }

  async findAll(query: QueryCouponDto) {
    const page = query.page ?? 1;
    const limit = Math.min(query.limit ?? 20, MAX_PAGE_SIZE);
    const [data, total] = await this.prisma.$transaction([
      this.prisma.coupon.findMany({
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.coupon.count(),
    ]);
    return {
      data,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  findOne(id: string) {
    return this.ensureExists(id);
  }

  async update(id: string, dto: UpdateCouponDto) {
    const existing = await this.ensureExists(id);

    const data: Prisma.CouponUpdateInput = {};
    if (dto.code !== undefined) {
      const code = this.normalize(dto.code);
      await this.ensureCodeFree(code, id);
      data.code = code;
    }
    // Re-validate value against whichever type will be in effect after the update.
    if (dto.type !== undefined || dto.value !== undefined) {
      const type = dto.type ?? existing.type;
      const value = dto.value ?? existing.value.toNumber();
      this.assertValueForType(type, value);
    }
    if (dto.type !== undefined) data.type = dto.type;
    if (dto.value !== undefined) data.value = dto.value;
    if (dto.minSubtotal !== undefined) data.minSubtotal = dto.minSubtotal;
    if (dto.maxUses !== undefined) data.maxUses = dto.maxUses;
    if (dto.expiresAt !== undefined) {
      data.expiresAt = dto.expiresAt ? new Date(dto.expiresAt) : null;
    }
    if (dto.isActive !== undefined) data.isActive = dto.isActive;

    return this.prisma.coupon.update({ where: { id }, data });
  }

  async remove(id: string): Promise<void> {
    await this.ensureExists(id);
    // Orders keep a foreign key to the coupon they used; deleting one that has
    // been redeemed would orphan that history, so block it (deactivate instead).
    const orders = await this.prisma.order.count({ where: { couponId: id } });
    if (orders > 0) {
      throw new ConflictException(
        'Cannot delete a coupon already used by orders',
      );
    }
    await this.prisma.coupon.delete({ where: { id } });
  }

  // ---- Customer preview ----

  // Validate a code against the caller's current cart and quote the discount,
  // without committing anything. The real redemption happens at checkout.
  async previewForUser(userId: string, code: string) {
    const { subtotal, currency } = await this.cartSubtotal(userId);
    const { coupon, discount, total } = await this.resolve(code, subtotal);
    return {
      code: coupon.code,
      type: coupon.type,
      currency,
      subtotal: subtotal.toFixed(2),
      discount: discount.toFixed(2),
      total: total.toFixed(2),
    };
  }

  // ---- Shared validation / pricing (used by preview and checkout) ----

  async resolve(
    code: string,
    subtotal: Prisma.Decimal,
    now: Date = new Date(),
  ): Promise<AppliedCoupon> {
    const coupon = await this.prisma.coupon.findUnique({
      where: { code: this.normalize(code) },
    });
    if (!coupon) {
      throw new NotFoundException('Coupon not found');
    }
    this.assertUsable(coupon, subtotal, now);
    const { discount, total } = this.price(coupon, subtotal);
    return { coupon, discount, total };
  }

  assertUsable(coupon: Coupon, subtotal: Prisma.Decimal, now: Date): void {
    if (!coupon.isActive) {
      throw new BadRequestException('Coupon is not active');
    }
    if (coupon.expiresAt && coupon.expiresAt.getTime() < now.getTime()) {
      throw new BadRequestException('Coupon has expired');
    }
    if (coupon.maxUses !== null && coupon.usedCount >= coupon.maxUses) {
      throw new BadRequestException('Coupon usage limit reached');
    }
    if (subtotal.lessThan(coupon.minSubtotal)) {
      throw new BadRequestException(
        `A minimum subtotal of ${coupon.minSubtotal.toFixed(2)} is required for this coupon`,
      );
    }
  }

  price(
    coupon: Coupon,
    subtotal: Prisma.Decimal,
  ): { discount: Prisma.Decimal; total: Prisma.Decimal } {
    let discount =
      coupon.type === CouponType.PERCENTAGE
        ? subtotal.mul(coupon.value).div(100)
        : new Prisma.Decimal(coupon.value);
    // A discount can never exceed the subtotal (no negative totals).
    if (discount.greaterThan(subtotal)) {
      discount = subtotal;
    }
    discount = discount.toDecimalPlaces(2);
    return { discount, total: subtotal.minus(discount) };
  }

  // ---- Helpers ----

  private normalize(code: string): string {
    return code.trim().toUpperCase();
  }

  private assertValueForType(type: CouponType, value: number): void {
    if (value <= 0) {
      throw new BadRequestException('Coupon value must be greater than zero');
    }
    if (type === CouponType.PERCENTAGE && value > 100) {
      throw new BadRequestException('A percentage coupon cannot exceed 100');
    }
  }

  private async ensureExists(id: string): Promise<Coupon> {
    const coupon = await this.prisma.coupon.findUnique({ where: { id } });
    if (!coupon) {
      throw new NotFoundException('Coupon not found');
    }
    return coupon;
  }

  private async ensureCodeFree(code: string, exceptId?: string): Promise<void> {
    const existing = await this.prisma.coupon.findUnique({ where: { code } });
    if (existing && existing.id !== exceptId) {
      throw new ConflictException('Coupon code is already in use');
    }
  }

  private async cartSubtotal(
    userId: string,
  ): Promise<{ subtotal: Prisma.Decimal; currency: string }> {
    const cart = await this.prisma.cart.findUnique({
      where: { userId },
      include: { items: { include: { product: true } } },
    });
    if (!cart || cart.items.length === 0) {
      throw new BadRequestException('Cart is empty');
    }
    let subtotal = new Prisma.Decimal(0);
    for (const item of cart.items) {
      subtotal = subtotal.plus(item.product.price.mul(item.quantity));
    }
    return { subtotal, currency: cart.items[0].product.currency };
  }
}
