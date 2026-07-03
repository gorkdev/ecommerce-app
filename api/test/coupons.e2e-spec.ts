import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { PaymentService } from '../src/payment/payment.service';

// Deterministic Stripe stub so checkout works without a key or network.
const paymentStub = {
  createPaymentIntent: ({ orderId }: { orderId: string }) =>
    Promise.resolve({ id: `pi_${orderId}`, client_secret: `secret_${orderId}` }),
  constructEvent: (payload: Buffer) => JSON.parse(payload.toString()),
};

describe('Coupons (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  const adminEmail = 'e2e-coupon-admin@example.com';
  const customerEmail = 'e2e-coupon-customer@example.com';
  const emails = [adminEmail, customerEmail];
  const password = 'supersecret1';

  const categorySlug = 'e2e-coupon-cat';
  const productSlug = 'e2e-coupon-product';
  const codes = ['E2E-SAVE10', 'E2E-MIN500', 'E2E-EXPIRED', 'E2E-TEMP'];

  let adminToken: string;
  let customerToken: string;
  let productId: string;

  const cleanup = async () => {
    const users = await prisma.user.findMany({
      where: { email: { in: emails } },
      select: { id: true },
    });
    const ids = users.map((u) => u.id);
    if (ids.length) {
      // Orders reference coupons; delete them before the coupons themselves.
      await prisma.order.deleteMany({ where: { userId: { in: ids } } });
    }
    await prisma.coupon.deleteMany({ where: { code: { in: codes } } });
    await prisma.user.deleteMany({ where: { email: { in: emails } } });
    await prisma.product.deleteMany({ where: { slug: productSlug } });
    await prisma.category.deleteMany({ where: { slug: categorySlug } });
  };

  const createCoupon = (token: string, body: Record<string, unknown>) =>
    request(app.getHttpServer())
      .post('/api/admin/coupons')
      .set('Authorization', `Bearer ${token}`)
      .send(body);

  const addToCart = (quantity: number) =>
    request(app.getHttpServer())
      .post('/api/cart/items')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ productId, quantity })
      .expect(201);

  const clearCart = () =>
    request(app.getHttpServer())
      .delete('/api/cart')
      .set('Authorization', `Bearer ${customerToken}`);

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

    const category = await request(app.getHttpServer())
      .post('/api/categories')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ name: 'Coupons', slug: categorySlug })
      .expect(201);

    const product = await request(app.getHttpServer())
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: 'Coupon Product',
        slug: productSlug,
        description: 'For coupon e2e',
        price: 100,
        stock: 20,
        categoryId: category.body.id,
      })
      .expect(201);
    productId = product.body.id;
  });

  afterAll(async () => {
    await cleanup();
    await app.close();
  });

  // ---- Admin CRUD ----

  let save10Id: string;

  it('forbids a non-admin from creating a coupon', async () => {
    await createCoupon(customerToken, {
      code: 'E2E-SAVE10',
      type: 'PERCENTAGE',
      value: 10,
    }).expect(403);
  });

  it('lets an admin create coupons (code is normalized to upper-case)', async () => {
    const res = await createCoupon(adminToken, {
      code: 'e2e-save10',
      type: 'PERCENTAGE',
      value: 10,
      maxUses: 1,
    }).expect(201);
    save10Id = res.body.id;
    expect(res.body.code).toBe('E2E-SAVE10');

    await createCoupon(adminToken, {
      code: 'E2E-MIN500',
      type: 'PERCENTAGE',
      value: 10,
      minSubtotal: 500,
    }).expect(201);

    await createCoupon(adminToken, {
      code: 'E2E-EXPIRED',
      type: 'FIXED',
      value: 20,
      expiresAt: '2020-01-01T00:00:00.000Z',
    }).expect(201);
  });

  it('rejects a percentage value over 100', async () => {
    await createCoupon(adminToken, {
      code: 'E2E-TOOBIG',
      type: 'PERCENTAGE',
      value: 150,
    }).expect(400);
  });

  it('rejects a duplicate code', async () => {
    await createCoupon(adminToken, {
      code: 'E2E-SAVE10',
      type: 'FIXED',
      value: 5,
    }).expect(409);
  });

  it('lets an admin list coupons', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/admin/coupons')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);
    expect(res.body.data.some((c: { id: string }) => c.id === save10Id)).toBe(
      true,
    );
  });

  // ---- Customer apply preview ----

  it('previews a percentage discount against the cart', async () => {
    await addToCart(2); // 2 * 100 = 200 subtotal

    const res = await request(app.getHttpServer())
      .post('/api/coupons/apply')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ code: 'e2e-save10' })
      .expect(201);

    expect(res.body.subtotal).toBe('200.00');
    expect(res.body.discount).toBe('20.00');
    expect(res.body.total).toBe('180.00');
  });

  it('404s an unknown code on apply', async () => {
    await request(app.getHttpServer())
      .post('/api/coupons/apply')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ code: 'E2E-DOES-NOT-EXIST' })
      .expect(404);
  });

  it('rejects a coupon whose minimum subtotal is not met', async () => {
    await request(app.getHttpServer())
      .post('/api/coupons/apply')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ code: 'E2E-MIN500' })
      .expect(400);
  });

  it('rejects an expired coupon', async () => {
    await request(app.getHttpServer())
      .post('/api/coupons/apply')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ code: 'E2E-EXPIRED' })
      .expect(400);
  });

  // ---- Checkout redemption ----

  it('applies the coupon at checkout and redeems one use', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/orders/checkout')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ couponCode: 'E2E-SAVE10' })
      .expect(201);

    expect(Number(res.body.order.subtotal)).toBe(200);
    expect(Number(res.body.order.discountTotal)).toBe(20);
    expect(Number(res.body.order.total)).toBe(180);
    expect(res.body.order.coupon.code).toBe('E2E-SAVE10');

    const coupon = await prisma.coupon.findUnique({ where: { id: save10Id } });
    expect(coupon!.usedCount).toBe(1);
  });

  it('refuses a coupon that has hit its usage cap', async () => {
    await addToCart(2);
    await request(app.getHttpServer())
      .post('/api/orders/checkout')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ couponCode: 'E2E-SAVE10' })
      .expect(400);
    await clearCart();
  });

  // ---- Admin delete ----

  it('deletes an unused coupon but blocks one used by an order', async () => {
    const temp = await createCoupon(adminToken, {
      code: 'E2E-TEMP',
      type: 'FIXED',
      value: 5,
    }).expect(201);

    await request(app.getHttpServer())
      .delete(`/api/admin/coupons/${temp.body.id}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(204);

    // E2E-SAVE10 was redeemed by the order above, so it cannot be deleted.
    await request(app.getHttpServer())
      .delete(`/api/admin/coupons/${save10Id}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(409);
  });
});
