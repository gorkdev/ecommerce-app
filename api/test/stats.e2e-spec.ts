import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { PaymentService } from '../src/payment/payment.service';

// Deterministic Stripe stub so the app boots without a key or network. The stats
// endpoint never touches payments, but AppModule wires the payment provider.
const paymentStub = {
  createPaymentIntent: ({ orderId }: { orderId: string }) =>
    Promise.resolve({ id: `pi_${orderId}`, client_secret: `secret_${orderId}` }),
  constructEvent: (payload: Buffer) => JSON.parse(payload.toString()),
};

// The suite runs against a shared DB alongside other e2e files, so global
// totals can only be asserted as lower bounds — never exact.
describe('Stats admin (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  const adminEmail = 'e2e-stats-admin@example.com';
  const customerEmail = 'e2e-stats-customer@example.com';
  const emails = [adminEmail, customerEmail];
  const password = 'supersecret1';
  const catSlug = 'e2e-stats-category';
  const productSlug = 'e2e-stats-lowstock';

  let adminToken: string;
  let customerToken: string;
  let customerId: string;

  const cleanup = async () => {
    const users = await prisma.user.findMany({
      where: { email: { in: emails } },
      select: { id: true },
    });
    const ids = users.map((u) => u.id);
    if (ids.length) {
      await prisma.order.deleteMany({ where: { userId: { in: ids } } });
    }
    await prisma.product.deleteMany({ where: { slug: productSlug } });
    await prisma.category.deleteMany({ where: { slug: catSlug } });
    await prisma.user.deleteMany({ where: { email: { in: emails } } });
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(PaymentService)
      .useValue(paymentStub)
      .compile();

    app = moduleRef.createNestApplication({ rawBody: true });
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        transform: true,
        forbidNonWhitelisted: true,
      }),
    );
    app.setGlobalPrefix('api');
    await app.init();

    prisma = app.get(PrismaService);
    await cleanup();

    await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email: adminEmail, password, name: 'Stats Admin' })
      .expect(201);
    await prisma.user.update({
      where: { email: adminEmail },
      data: { role: 'ADMIN' },
    });
    const adminLogin = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email: adminEmail, password })
      .expect(200);
    adminToken = adminLogin.body.accessToken;

    const customerReg = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email: customerEmail, password, name: 'Stats Customer' })
      .expect(201);
    customerToken = customerReg.body.accessToken;
    customerId = customerReg.body.user.id;

    // Seed one low-stock product and one paid order so revenue and the
    // low-stock list have something concrete to report.
    const category = await prisma.category.create({
      data: { slug: catSlug, name: 'Stats Category' },
    });
    await prisma.product.create({
      data: {
        slug: productSlug,
        name: 'Low Stock Widget',
        description: 'Nearly sold out.',
        price: '19.99',
        currency: 'TRY',
        stock: 2,
        isActive: true,
        categoryId: category.id,
      },
    });
    await prisma.order.create({
      data: {
        userId: customerId,
        status: 'PAID',
        subtotal: '100.00',
        total: '100.00',
        currency: 'TRY',
      },
    });
  });

  afterAll(async () => {
    await cleanup();
    await app.close();
  });

  const getStats = (token: string) =>
    request(app.getHttpServer())
      .get('/api/admin/stats')
      .set('Authorization', `Bearer ${token}`);

  it('forbids a non-admin from reading the dashboard stats', async () => {
    await getStats(customerToken).expect(403);
  });

  it('returns revenue and headline counts as lower bounds', async () => {
    const res = await getStats(adminToken).expect(200);

    expect(res.body.revenue.currency).toBe('TRY');
    // The seeded PAID order guarantees at least 100 in collected revenue.
    expect(Number(res.body.revenue.total)).toBeGreaterThanOrEqual(100);

    expect(res.body.counts.users).toBeGreaterThanOrEqual(2);
    expect(res.body.counts.orders).toBeGreaterThanOrEqual(1);
    expect(res.body.counts.products).toBeGreaterThanOrEqual(1);
    expect(res.body.counts.lowStock).toBeGreaterThanOrEqual(1);
  });

  it('breaks orders down across the full status pipeline', async () => {
    const res = await getStats(adminToken).expect(200);

    const statuses = [
      'PENDING',
      'PAID',
      'PREPARING',
      'SHIPPED',
      'DELIVERED',
      'CANCELLED',
      'REFUNDED',
    ];
    for (const status of statuses) {
      expect(typeof res.body.ordersByStatus[status]).toBe('number');
    }
    expect(res.body.ordersByStatus.PAID).toBeGreaterThanOrEqual(1);
  });

  it('lists recent orders without leaking the customer password hash', async () => {
    const res = await getStats(adminToken).expect(200);

    expect(Array.isArray(res.body.recentOrders)).toBe(true);
    expect(res.body.recentOrders.length).toBeGreaterThanOrEqual(1);
    expect(res.body.recentOrders.length).toBeLessThanOrEqual(5);
    for (const order of res.body.recentOrders) {
      expect(order.user).toBeDefined();
      expect(order.user.passwordHash).toBeUndefined();
      expect(order.user).toEqual(
        expect.objectContaining({
          id: expect.any(String),
          email: expect.any(String),
          name: expect.any(String),
        }),
      );
    }
  });

  it('lists low-stock products under the threshold', async () => {
    const res = await getStats(adminToken).expect(200);

    expect(Array.isArray(res.body.lowStockProducts)).toBe(true);
    expect(res.body.lowStockProducts.length).toBeGreaterThanOrEqual(1);
    expect(res.body.lowStockProducts.length).toBeLessThanOrEqual(5);
    for (const product of res.body.lowStockProducts) {
      expect(product.stock).toBeLessThan(5);
      expect(product.passwordHash).toBeUndefined();
    }
  });
});
