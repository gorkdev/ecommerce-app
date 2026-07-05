import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentService } from '../payment/payment.service';
import { CouponService } from '../coupon/coupon.service';
import { Prisma, OrderStatus } from '../generated/prisma/client';
import { CheckoutDto } from './dto/checkout.dto';
import { QueryOrderDto } from './dto/query-order.dto';

const MAX_PAGE_SIZE = 100;

const ORDER_INCLUDE = {
  items: {
    include: {
      product: {
        select: {
          id: true,
          slug: true,
          images: { orderBy: { sortOrder: 'asc' as const }, take: 1 },
        },
      },
    },
  },
  address: true,
  coupon: { select: { id: true, code: true, type: true } },
} satisfies Prisma.OrderInclude;

// Admin views also need to know who placed the order. A narrow select keeps
// sensitive columns (passwordHash) out of the response.
const ADMIN_ORDER_INCLUDE = {
  ...ORDER_INCLUDE,
  user: { select: { id: true, email: true, name: true } },
} satisfies Prisma.OrderInclude;

// Which status moves the admin (or the system) is allowed to make. Payment
// flips PENDING -> PAID via the webhook; everything past that is fulfilment.
const ALLOWED_TRANSITIONS: Record<OrderStatus, OrderStatus[]> = {
  PENDING: [OrderStatus.PAID, OrderStatus.CANCELLED],
  PAID: [OrderStatus.PREPARING, OrderStatus.CANCELLED, OrderStatus.REFUNDED],
  PREPARING: [OrderStatus.SHIPPED, OrderStatus.CANCELLED],
  SHIPPED: [OrderStatus.DELIVERED],
  DELIVERED: [OrderStatus.REFUNDED],
  CANCELLED: [],
  REFUNDED: [],
};

@Injectable()
export class OrderService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly payment: PaymentService,
    private readonly coupons: CouponService,
  ) {}

  // Turn the user's cart into a PENDING order and open a Stripe PaymentIntent.
  // Stock is reserved here; the order only becomes PAID via the webhook.
  async checkout(userId: string, dto: CheckoutDto) {
    const cart = await this.prisma.cart.findUnique({
      where: { userId },
      include: { items: { include: { product: true } } },
    });
    if (!cart || cart.items.length === 0) {
      throw new BadRequestException('Cart is empty');
    }
    if (dto.addressId) {
      await this.ensureAddress(userId, dto.addressId);
    }

    for (const item of cart.items) {
      if (!item.product.isActive) {
        throw new BadRequestException(
          `"${item.product.name}" is no longer available`,
        );
      }
      if (item.quantity > item.product.stock) {
        throw new BadRequestException(
          `Not enough stock for "${item.product.name}"`,
        );
      }
    }

    let subtotal = new Prisma.Decimal(0);
    for (const item of cart.items) {
      subtotal = subtotal.plus(item.product.price.mul(item.quantity));
    }

    // A coupon code (optional) is validated against the subtotal here and
    // atomically redeemed inside the transaction below.
    let discountTotal = new Prisma.Decimal(0);
    let couponId: string | null = null;
    let couponMaxUses: number | null = null;
    if (dto.couponCode) {
      const applied = await this.coupons.resolve(dto.couponCode, subtotal);
      discountTotal = applied.discount;
      couponId = applied.coupon.id;
      couponMaxUses = applied.coupon.maxUses;
    }
    const total = subtotal.minus(discountTotal);
    const currency = cart.items[0].product.currency;

    const order = await this.prisma.$transaction(async (tx) => {
      // Atomic conditional decrement guards against overselling under races:
      // the row only updates while stock still covers the requested quantity.
      for (const item of cart.items) {
        const updated = await tx.product.updateMany({
          where: { id: item.productId, stock: { gte: item.quantity } },
          data: { stock: { decrement: item.quantity } },
        });
        if (updated.count === 0) {
          throw new BadRequestException(
            `Not enough stock for "${item.product.name}"`,
          );
        }
      }

      // Redeem the coupon under the same guard: the conditional update only
      // bumps usedCount while the usage cap still has room, so concurrent
      // checkouts can't push a limited coupon past maxUses.
      if (couponId) {
        const where: Prisma.CouponWhereInput = { id: couponId, isActive: true };
        if (couponMaxUses !== null) {
          where.usedCount = { lt: couponMaxUses };
        }
        const bumped = await tx.coupon.updateMany({
          where,
          data: { usedCount: { increment: 1 } },
        });
        if (bumped.count === 0) {
          throw new BadRequestException('Coupon is no longer available');
        }
      }

      const created = await tx.order.create({
        data: {
          userId,
          status: OrderStatus.PENDING,
          subtotal,
          discountTotal,
          total,
          currency,
          addressId: dto.addressId ?? null,
          couponId,
          items: {
            create: cart.items.map((item) => ({
              productId: item.productId,
              nameSnapshot: item.product.name,
              priceSnapshot: item.product.price,
              quantity: item.quantity,
            })),
          },
        },
        include: ORDER_INCLUDE,
      });

      await tx.cartItem.deleteMany({ where: { cartId: cart.id } });
      return created;
    });

    // External call kept outside the DB transaction.
    const amountMinor = Math.round(total.mul(100).toNumber());
    const intent = await this.payment.createPaymentIntent({
      amountMinor,
      currency,
      orderId: order.id,
    });
    await this.prisma.order.update({
      where: { id: order.id },
      data: { stripePaymentIntentId: intent.id },
    });

    return {
      order: { ...order, stripePaymentIntentId: intent.id },
      clientSecret: intent.client_secret,
    };
  }

  findMine(userId: string) {
    return this.prisma.order.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      include: ORDER_INCLUDE,
    });
  }

  async findOneForUser(userId: string, orderId: string) {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, userId },
      include: ORDER_INCLUDE,
    });
    if (!order) {
      throw new NotFoundException('Order not found');
    }
    return order;
  }

  // ---- Admin ----

  async findAll(query: QueryOrderDto) {
    const page = query.page ?? 1;
    const limit = Math.min(query.limit ?? 20, MAX_PAGE_SIZE);
    const where: Prisma.OrderWhereInput = {};
    if (query.status) {
      where.status = query.status;
    }

    const [data, total] = await this.prisma.$transaction([
      this.prisma.order.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        include: ADMIN_ORDER_INCLUDE,
      }),
      this.prisma.order.count({ where }),
    ]);

    return {
      data,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  async updateStatus(orderId: string, status: OrderStatus) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
    });
    if (!order) {
      throw new NotFoundException('Order not found');
    }
    if (!ALLOWED_TRANSITIONS[order.status].includes(status)) {
      throw new BadRequestException(
        `Cannot move an order from ${order.status} to ${status}`,
      );
    }
    return this.prisma.order.update({
      where: { id: orderId },
      data: { status },
      include: ADMIN_ORDER_INCLUDE,
    });
  }

  // ---- Webhook-driven state (called by the Stripe webhook controller) ----

  // Idempotent: a duplicate succeeded event leaves an already-paid order alone.
  async markPaid(paymentIntentId: string): Promise<void> {
    const order = await this.prisma.order.findUnique({
      where: { stripePaymentIntentId: paymentIntentId },
    });
    if (!order || order.status !== OrderStatus.PENDING) {
      return;
    }
    await this.prisma.order.update({
      where: { id: order.id },
      data: { status: OrderStatus.PAID },
    });
  }

  // A failed payment cancels the pending order and returns its reserved stock.
  async markPaymentFailed(paymentIntentId: string): Promise<void> {
    const order = await this.prisma.order.findUnique({
      where: { stripePaymentIntentId: paymentIntentId },
      include: { items: true },
    });
    if (!order || order.status !== OrderStatus.PENDING) {
      return;
    }
    await this.prisma.$transaction(async (tx) => {
      for (const item of order.items) {
        await tx.product.update({
          where: { id: item.productId },
          data: { stock: { increment: item.quantity } },
        });
      }
      await tx.order.update({
        where: { id: order.id },
        data: { status: OrderStatus.CANCELLED },
      });
    });
  }

  private async ensureAddress(userId: string, addressId: string) {
    const address = await this.prisma.address.findFirst({
      where: { id: addressId, userId },
    });
    if (!address) {
      throw new NotFoundException('Address not found');
    }
  }
}
