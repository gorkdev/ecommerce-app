import { Test } from '@nestjs/testing';
import { StatsService } from './stats.service';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma, OrderStatus } from '../generated/prisma/client';

type PrismaMock = {
  order: {
    aggregate: jest.Mock;
    count: jest.Mock;
    groupBy: jest.Mock;
    findMany: jest.Mock;
  };
  user: { count: jest.Mock };
  product: { count: jest.Mock; findMany: jest.Mock };
  $transaction: jest.Mock;
};

describe('StatsService', () => {
  let service: StatsService;
  let prisma: PrismaMock;

  beforeEach(async () => {
    prisma = {
      order: {
        aggregate: jest.fn().mockReturnValue({
          _sum: { total: new Prisma.Decimal('1250.50') },
        }),
        // Called twice: total orders, then pending orders.
        count: jest.fn().mockReturnValueOnce(42).mockReturnValueOnce(7),
        groupBy: jest.fn().mockReturnValue([
          { status: OrderStatus.PENDING, _count: 7 },
          { status: OrderStatus.DELIVERED, _count: 12 },
        ]),
        findMany: jest.fn().mockReturnValue([{ id: 'o1' }]),
      },
      user: { count: jest.fn().mockReturnValue(9) },
      product: {
        // Called twice: total products, then low-stock products.
        count: jest.fn().mockReturnValueOnce(30).mockReturnValueOnce(4),
        findMany: jest.fn().mockReturnValue([{ id: 'p1', stock: 1 }]),
      },
      // The service passes an array of query builders; resolve them in order so
      // the destructured tuple lines up positionally, exactly like a real tx.
      $transaction: jest.fn((ops: unknown[]) => Promise.resolve(ops)),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        StatsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = moduleRef.get(StatsService);
  });

  it('reports collected revenue and headline counts', async () => {
    const res = await service.getOverview();

    expect(res.revenue.total.toString()).toBe('1250.5');
    expect(res.revenue.currency).toBe('TRY');
    expect(res.counts).toEqual({
      orders: 42,
      pendingOrders: 7,
      users: 9,
      products: 30,
      lowStock: 4,
    });
    expect(res.recentOrders).toEqual([{ id: 'o1' }]);
    expect(res.lowStockProducts).toEqual([{ id: 'p1', stock: 1 }]);
  });

  it('counts revenue only from paid-through-delivered orders', async () => {
    await service.getOverview();

    const arg = prisma.order.aggregate.mock.calls[0][0];
    expect(arg._sum).toEqual({ total: true });
    expect(arg.where).toEqual({
      status: {
        in: [
          OrderStatus.PAID,
          OrderStatus.PREPARING,
          OrderStatus.SHIPPED,
          OrderStatus.DELIVERED,
        ],
      },
    });
  });

  it('treats revenue as zero when there are no paid orders', async () => {
    prisma.order.aggregate.mockReturnValue({ _sum: { total: null } });

    const res = await service.getOverview();

    expect(res.revenue.total.toString()).toBe('0');
  });

  it('flags active products below the low-stock threshold', async () => {
    await service.getOverview();

    // Second product.count call is the low-stock count.
    expect(prisma.product.count.mock.calls[1][0]).toEqual({
      where: { isActive: true, stock: { lt: 5 } },
    });
    // The list uses the same predicate, ordered by stock ascending.
    const listArg = prisma.product.findMany.mock.calls[0][0];
    expect(listArg.where).toEqual({ isActive: true, stock: { lt: 5 } });
    expect(listArg.orderBy).toEqual({ stock: 'asc' });
    expect(listArg.take).toBe(5);
  });

  it('returns a full status pipeline with zeros for empty statuses', async () => {
    const res = await service.getOverview();

    // Every OrderStatus present, including ones with no orders.
    expect(Object.keys(res.ordersByStatus).sort()).toEqual(
      Object.values(OrderStatus).sort(),
    );
    expect(res.ordersByStatus.PENDING).toBe(7);
    expect(res.ordersByStatus.DELIVERED).toBe(12);
    expect(res.ordersByStatus.CANCELLED).toBe(0);
    expect(res.ordersByStatus.REFUNDED).toBe(0);
  });

  it('never exposes the password hash on recent-order customers', async () => {
    await service.getOverview();

    const select = prisma.order.findMany.mock.calls[0][0].select;
    expect(select.take).toBeUndefined();
    expect(select.user.select.passwordHash).toBeUndefined();
    expect(select.user.select).toEqual({
      id: true,
      email: true,
      name: true,
    });
    expect(prisma.order.findMany.mock.calls[0][0].take).toBe(5);
  });
});
