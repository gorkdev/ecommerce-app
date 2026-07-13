import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { PaymentService } from '../src/payment/payment.service';
import { PushService } from '../src/notification/push.service';

// Stripe stub, same shape the orders e2e uses: deterministic intents and a
// constructEvent that parses the raw body so tests can craft webhook events.
const paymentStub = {
  createPaymentIntent: ({ orderId }: { orderId: string }) =>
    Promise.resolve({ id: `pi_${orderId}`, client_secret: `secret_${orderId}` }),
  constructEvent: (payload: Buffer) => JSON.parse(payload.toString()),
};

// Firebase stub: records every multicast instead of calling Google. Tests
// flip the resolved value to simulate dead-token responses.
const pushStub = {
  enabled: true,
  sendToTokens: jest.fn(),
};

// Pushes are fired after the HTTP response (fire-and-forget), so assertions
// poll instead of racing the background promise.
const until = async (check: () => boolean | Promise<boolean>) => {
  const deadline = Date.now() + 2000;
  while (!(await check())) {
    if (Date.now() > deadline) {
      throw new Error('Condition not met within 2s');
    }
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
};

describe('Notifications (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  const adminEmail = 'e2e-notif-admin@example.com';
  const customerEmail = 'e2e-notif-customer@example.com';
  const otherEmail = 'e2e-notif-other@example.com';
  const emails = [adminEmail, customerEmail, otherEmail];
  const password = 'supersecret1';

  const categorySlug = 'e2e-notif-cat';
  const productSlug = 'e2e-notif-product';

  const sharedToken = 'e2e-notif-shared-device';
  const trToken = 'e2e-notif-tr-device';

  let adminToken: string;
  let customerToken: string;
  let otherToken: string;
  let productId: string;

  const stripeEvent = (type: string, paymentIntentId: string) => ({
    type,
    data: { object: { id: paymentIntentId } },
  });

  const cleanup = async () => {
    const users = await prisma.user.findMany({
      where: { email: { in: emails } },
      select: { id: true },
    });
    const ids = users.map((u) => u.id);
    if (ids.length) {
      await prisma.order.deleteMany({ where: { userId: { in: ids } } });
    }
    // Device tokens cascade with their users.
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
      .overrideProvider(PushService)
      .useValue(pushStub)
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

    const otherReg = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email: otherEmail, password, name: 'Other' })
      .expect(201);
    otherToken = otherReg.body.accessToken;

    const category = await request(app.getHttpServer())
      .post('/api/categories')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ name: 'Notifications', slug: categorySlug })
      .expect(201);
    const product = await request(app.getHttpServer())
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: 'Notif Product',
        slug: productSlug,
        description: 'For notification e2e',
        price: 10,
        stock: 5,
        categoryId: category.body.id,
      })
      .expect(201);
    productId = product.body.id;
  });

  afterAll(async () => {
    await cleanup();
    await app.close();
  });

  beforeEach(() => {
    pushStub.sendToTokens
      .mockReset()
      .mockResolvedValue({ successCount: 1, invalidTokens: [] });
  });

  // ---- Device token registration ----

  it('requires auth to register a device token', async () => {
    await request(app.getHttpServer())
      .post('/api/notifications/tokens')
      .send({ token: sharedToken, platform: 'android' })
      .expect(401);
  });

  it('rejects an unknown platform', async () => {
    await request(app.getHttpServer())
      .post('/api/notifications/tokens')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ token: sharedToken, platform: 'windows' })
      .expect(400);
  });

  it('registers a token and defaults its language to English', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/notifications/tokens')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ token: sharedToken, platform: 'android' })
      .expect(201);

    expect(res.body.token).toBe(sharedToken);
    expect(res.body.locale).toBe('en');
  });

  it('moves the token when another account signs in on the device', async () => {
    await request(app.getHttpServer())
      .post('/api/notifications/tokens')
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ token: sharedToken, platform: 'android', locale: 'tr' })
      .expect(201);

    const row = await prisma.deviceToken.findUnique({
      where: { token: sharedToken },
    });
    const other = await prisma.user.findUnique({
      where: { email: otherEmail },
    });
    expect(row!.userId).toBe(other!.id);
    expect(row!.locale).toBe('tr');
  });

  it('ignores a delete from a user who does not own the token', async () => {
    await request(app.getHttpServer())
      .delete(`/api/notifications/tokens/${sharedToken}`)
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(204);

    const row = await prisma.deviceToken.findUnique({
      where: { token: sharedToken },
    });
    expect(row).not.toBeNull();
  });

  it('deletes the token for its owner on sign-out', async () => {
    await request(app.getHttpServer())
      .delete(`/api/notifications/tokens/${sharedToken}`)
      .set('Authorization', `Bearer ${otherToken}`)
      .expect(204);

    const row = await prisma.deviceToken.findUnique({
      where: { token: sharedToken },
    });
    expect(row).toBeNull();
  });

  // ---- Order lifecycle pushes ----

  let orderId: string;

  it('pushes a localized PAID notification after the payment webhook', async () => {
    await request(app.getHttpServer())
      .post('/api/notifications/tokens')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ token: trToken, platform: 'android', locale: 'tr' })
      .expect(201);

    await request(app.getHttpServer())
      .post('/api/cart/items')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ productId, quantity: 1 })
      .expect(201);
    const checkout = await request(app.getHttpServer())
      .post('/api/orders/checkout')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({})
      .expect(201);
    orderId = checkout.body.order.id;

    await request(app.getHttpServer())
      .post('/api/payments/webhook')
      .set('stripe-signature', 'test-sig')
      .send(stripeEvent('payment_intent.succeeded', `pi_${orderId}`))
      .expect(200);

    await until(() => pushStub.sendToTokens.mock.calls.length > 0);
    expect(pushStub.sendToTokens).toHaveBeenCalledWith([trToken], {
      title: 'Ödeme alındı',
      body: 'Siparişiniz onaylandı, hazırlamaya başlıyoruz.',
      data: { type: 'order-status', orderId, status: 'PAID' },
    });
  });

  it('pushes when the admin advances fulfilment', async () => {
    await request(app.getHttpServer())
      .patch(`/api/admin/orders/${orderId}/status`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ status: 'PREPARING' })
      .expect(200);

    await until(() => pushStub.sendToTokens.mock.calls.length > 0);
    expect(pushStub.sendToTokens).toHaveBeenCalledWith(
      [trToken],
      expect.objectContaining({ title: 'Sipariş güncellendi' }),
    );
  });

  it('prunes a token Firebase reports as dead', async () => {
    pushStub.sendToTokens.mockResolvedValue({
      successCount: 0,
      invalidTokens: [trToken],
    });

    await request(app.getHttpServer())
      .patch(`/api/admin/orders/${orderId}/status`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ status: 'SHIPPED' })
      .expect(200);

    await until(async () => {
      const row = await prisma.deviceToken.findUnique({
        where: { token: trToken },
      });
      return row === null;
    });
  });
});
