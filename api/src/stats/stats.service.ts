import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma, OrderStatus } from '../generated/prisma/client';

// A product with fewer than this many units on hand is flagged for restocking.
const LOW_STOCK_THRESHOLD = 5;

// How many rows the two "latest activity" lists surface on the dashboard.
const RECENT_ORDERS_TAKE = 5;
const LOW_STOCK_TAKE = 5;

// Revenue only counts money actually collected and still held: an order must have
// been paid, and REFUNDED/CANCELLED/PENDING are excluded. The store is
// single-currency (TRY default everywhere), so a plain sum is accurate here.
const REVENUE_STATUSES: OrderStatus[] = [
  OrderStatus.PAID,
  OrderStatus.PREPARING,
  OrderStatus.SHIPPED,
  OrderStatus.DELIVERED,
];

// The customer-facing columns admins may see for a recent order — a narrow
// select keeps sensitive fields (passwordHash) out of the payload.
const RECENT_ORDER_SELECT = {
  id: true,
  status: true,
  total: true,
  currency: true,
  createdAt: true,
  user: { select: { id: true, email: true, name: true } },
} satisfies Prisma.OrderSelect;

@Injectable()
export class StatsService {
  constructor(private readonly prisma: PrismaService) {}

  // One round-trip snapshot for the admin dashboard: revenue, headline counts,
  // the order pipeline broken down by status, and the two "needs a look" lists.
  async getOverview() {
    const lowStockWhere: Prisma.ProductWhereInput = {
      isActive: true,
      stock: { lt: LOW_STOCK_THRESHOLD },
    };

    const [
      revenueAgg,
      orders,
      pendingOrders,
      users,
      products,
      lowStock,
      statusGroups,
      recentOrders,
      lowStockProducts,
    ] = await this.prisma.$transaction([
      this.prisma.order.aggregate({
        _sum: { total: true },
        where: { status: { in: REVENUE_STATUSES } },
      }),
      this.prisma.order.count(),
      this.prisma.order.count({ where: { status: OrderStatus.PENDING } }),
      this.prisma.user.count(),
      this.prisma.product.count(),
      this.prisma.product.count({ where: lowStockWhere }),
      this.prisma.order.groupBy({
        by: ['status'],
        _count: true,
        orderBy: { status: 'asc' },
      }),
      this.prisma.order.findMany({
        orderBy: { createdAt: 'desc' },
        take: RECENT_ORDERS_TAKE,
        select: RECENT_ORDER_SELECT,
      }),
      this.prisma.product.findMany({
        where: lowStockWhere,
        orderBy: { stock: 'asc' },
        take: LOW_STOCK_TAKE,
        select: {
          id: true,
          slug: true,
          name: true,
          stock: true,
          price: true,
          currency: true,
        },
      }),
    ]);

    // Seed every status at 0 so the client always renders the full pipeline,
    // then overlay the statuses that actually have orders.
    const ordersByStatus = Object.fromEntries(
      Object.values(OrderStatus).map((status) => [status, 0]),
    ) as Record<OrderStatus, number>;
    for (const group of statusGroups) {
      // `_count: true` yields a number at runtime; Prisma's groupBy return type
      // widens it, so coerce to keep the map strictly numeric.
      ordersByStatus[group.status] = Number(group._count);
    }

    return {
      revenue: {
        total: revenueAgg._sum.total ?? new Prisma.Decimal(0),
        currency: 'TRY',
      },
      counts: { orders, pendingOrders, users, products, lowStock },
      ordersByStatus,
      recentOrders,
      lowStockProducts,
    };
  }
}
