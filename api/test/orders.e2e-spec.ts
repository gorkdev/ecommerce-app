import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { PaymentService } from '../src/payment/payment.service';

// The Stripe SDK is replaced with a deterministic stub: createPaymentIntent
// echoes an id derived from the order, and constructEvent simply parses the
// raw body (skipping signature verification) so tests can craft events.
const paymentStub = {
  createPaymentIntent: ({ orderId }: { orderId: string }) =>
    Promise.resolve({ id: `pi_${orderId}`, client_secret: `secret_${orderId}` }),
  constructEvent: (payload: Buffer) => JSON.parse(payload.toString()),
};

describe('Orders + Stripe (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  const adminEmail = 'e2e-order-admin@example.com';
  const customerEmail = 'e2e-order-customer@example.com';
  const emails = [adminEmail, customerEmail];
  const password = 'supersecret1';

  const categorySlug = 'e2e-order-cat';
  const productSlug = 'e2e-order-product';

  let adminToken: string;
  let customerToken: string;
  let productId: string;
  let addressId: string;

  const stripeEvent = (type: string, paymentIntentId: string) => ({
    type,
    data: { object: { id: paymentIntentId } },
  });

  const stock = async () => {
    const product = await prisma.product.findUnique({
      where: { id: productId },
    });
    return product!.stock;
  };

  const cleanup = async () => {
    const users = await prisma.user.findMany({
      where: { email: { in: emails } },
      select: { id: true },
    });
    const ids = users.map((u) => u.id);
    if (ids.length) {
      await prisma.order.deleteMany({ where: { userId: { in: ids } } });
    }
    await prisma.user.deleteMany({ where: { email: { in: emails } } });
    await prisma.product.deleteMany({ where: { slug: productSlug } });
    await prisma.category.deleteMany({ where: { slug: categorySlug } });
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

    // Admin seeds the catalog.
    await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email: adminEmail, password, name: 'Admin' })
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
      .send({ email: customerEmail, password, name: 'Customer' })
      .expect(201);
    customerToken = customerReg.body.accessToken;

    const customer = await prisma.user.findUnique({
      where: { email: customerEmail },
    });
    const address = await prisma.address.create({
      data: {
        userId: customer!.id,
        fullName: 'Customer',
        phone: '+900000000000',
        line1: 'Test 1',
        city: 'Istanbul',
        district: 'Kadikoy',
        postalCode: '34000',
      },
    });
    addressId = address.id;

    const category = await request(app.getHttpServer())
      .post('/api/categories')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ name: 'Orders', slug: categorySlug })
      .expect(201);

    const product = await request(app.getHttpServer())
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: 'Order Product',
        slug: productSlug,
        description: 'For order e2e',
        price: 25,
        stock: 3,
        categoryId: category.body.id,
      })
      .expect(201);
    productId = product.body.id;
  });

  afterAll(async () => {
    await cleanup();
    await app.close();
  });

  const addToCart = (quantity: number) =>
    request(app.getHttpServer())
      .post('/api/cart/items')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ productId, quantity })
      .expect(201);

  // ---- Checkout ----

  it('requires auth to checkout', async () => {
    await request(app.getHttpServer())
      .post('/api/orders/checkout')
      .send({})
      .expect(401);
  });

  it('rejects checkout with an empty cart', async () => {
    await request(app.getHttpServer())
      .post('/api/orders/checkout')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({})
      .expect(400);
  });

  let orderAId: string;
  let intentAId: string;

  it('creates a PENDING order, reserves stock, and returns a client secret', async () => {
    await addToCart(2);

    const res = await request(app.getHttpServer())
      .post('/api/orders/checkout')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({})
      .expect(201);

    orderAId = res.body.order.id;
    expect(res.body.order.status).toBe('PENDING');
    expect(Number(res.body.order.total)).toBe(50);
    expect(res.body.clientSecret).toBeTruthy();
    expect(await stock()).toBe(1); // 3 - 2 reserved
  });

  it('lists the order for its owner', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/orders')
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(200);

    expect(res.body.some((o: { id: string }) => o.id === orderAId)).toBe(true);
  });

  it('returns the order detail with the stored payment intent', async () => {
    const res = await request(app.getHttpServer())
      .get(`/api/orders/${orderAId}`)
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(200);

    intentAId = res.body.stripePaymentIntentId;
    expect(intentAId).toBeTruthy();
    expect(res.body.items).toHaveLength(1);
  });

  it('404s for an order the user does not own', async () => {
    await request(app.getHttpServer())
      .get('/api/orders/does-not-exist')
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(404);
  });

  // ---- Webhook ----

  it('marks the order PAID on payment_intent.succeeded', async () => {
    await request(app.getHttpServer())
      .post('/api/payments/webhook')
      .set('stripe-signature', 'test-sig')
      .send(stripeEvent('payment_intent.succeeded', intentAId))
      .expect(200);

    const res = await request(app.getHttpServer())
      .get(`/api/orders/${orderAId}`)
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(200);
    expect(res.body.status).toBe('PAID');
  });

  it('is idempotent for a repeated succeeded event', async () => {
    await request(app.getHttpServer())
      .post('/api/payments/webhook')
      .set('stripe-signature', 'test-sig')
      .send(stripeEvent('payment_intent.succeeded', intentAId))
      .expect(200);

    const res = await request(app.getHttpServer())
      .get(`/api/orders/${orderAId}`)
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(200);
    expect(res.body.status).toBe('PAID');
  });

  // ---- Admin ----

  it('forbids a customer from the admin order list', async () => {
    await request(app.getHttpServer())
      .get('/api/admin/orders')
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(403);
  });

  it('lets an admin list orders', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/admin/orders')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    const row = res.body.data.find((o: { id: string }) => o.id === orderAId);
    expect(row).toBeDefined();
    // Admin rows carry the customer identity (narrow select, no passwordHash).
    expect(row.user.email).toBe(customerEmail);
    expect(row.user.passwordHash).toBeUndefined();
  });

  it('advances a PAID order to PREPARING', async () => {
    const res = await request(app.getHttpServer())
      .patch(`/api/admin/orders/${orderAId}/status`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ status: 'PREPARING' })
      .expect(200);

    expect(res.body.status).toBe('PREPARING');
  });

  it('rejects an illegal status transition', async () => {
    await request(app.getHttpServer())
      .patch(`/api/admin/orders/${orderAId}/status`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ status: 'DELIVERED' })
      .expect(400);
  });

  // ---- Address validation + failed payment ----

  it('404s when checking out with an address the user does not own', async () => {
    await addToCart(1);
    await request(app.getHttpServer())
      .post('/api/orders/checkout')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ addressId: 'not-mine' })
      .expect(404);
  });

  let orderBId: string;
  let intentBId: string;

  it('checks out with a valid address (cart still intact after the 404)', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/orders/checkout')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ addressId })
      .expect(201);

    orderBId = res.body.order.id;
    expect(res.body.order.address.id).toBe(addressId);
    expect(await stock()).toBe(0); // 1 - 1 reserved
  });

  it('cancels the order and restocks on payment_intent.payment_failed', async () => {
    const detail = await request(app.getHttpServer())
      .get(`/api/orders/${orderBId}`)
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(200);
    intentBId = detail.body.stripePaymentIntentId;

    await request(app.getHttpServer())
      .post('/api/payments/webhook')
      .set('stripe-signature', 'test-sig')
      .send(stripeEvent('payment_intent.payment_failed', intentBId))
      .expect(200);

    const res = await request(app.getHttpServer())
      .get(`/api/orders/${orderBId}`)
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(200);
    expect(res.body.status).toBe('CANCELLED');
    expect(await stock()).toBe(1); // restored
  });
});
