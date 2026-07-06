import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { PaymentService } from '../src/payment/payment.service';

// Deterministic Stripe stub so the app boots without a key or network. The user
// endpoints never touch payments, but AppModule wires the payment provider.
const paymentStub = {
  createPaymentIntent: ({ orderId }: { orderId: string }) =>
    Promise.resolve({ id: `pi_${orderId}`, client_secret: `secret_${orderId}` }),
  constructEvent: (payload: Buffer) => JSON.parse(payload.toString()),
};

describe('Users admin (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  const adminEmail = 'e2e-user-admin@example.com';
  const customerEmail = 'e2e-user-customer@example.com';
  const emails = [adminEmail, customerEmail];
  const password = 'supersecret1';

  let adminToken: string;
  let customerToken: string;
  let adminId: string;
  let customerId: string;

  const cleanup = async () => {
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
      .send({ email: adminEmail, password, name: 'User Admin' })
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
    adminId = adminLogin.body.user.id;

    const customerReg = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email: customerEmail, password, name: 'Jane Customer' })
      .expect(201);
    customerToken = customerReg.body.accessToken;
    customerId = customerReg.body.user.id;
  });

  afterAll(async () => {
    await cleanup();
    await app.close();
  });

  const listUsers = (token: string, query = '') =>
    request(app.getHttpServer())
      .get(`/api/admin/users${query}`)
      .set('Authorization', `Bearer ${token}`);

  it('forbids a non-admin from listing users', async () => {
    await listUsers(customerToken).expect(403);
  });

  it('lists users with counts and without the password hash', async () => {
    const res = await listUsers(adminToken).expect(200);

    const row = res.body.data.find(
      (u: { id: string }) => u.id === customerId,
    );
    expect(row).toBeDefined();
    expect(row.email).toBe(customerEmail);
    expect(row.passwordHash).toBeUndefined();
    expect(row._count).toEqual(
      expect.objectContaining({ orders: expect.any(Number) }),
    );
    expect(res.body.meta).toEqual(
      expect.objectContaining({ page: 1, limit: 20 }),
    );
  });

  it('narrows the list with a case-insensitive search', async () => {
    const res = await listUsers(adminToken, '?search=JANE').expect(200);

    const emailsInResult = res.body.data.map((u: { email: string }) => u.email);
    expect(emailsInResult).toContain(customerEmail);
    expect(emailsInResult).not.toContain(adminEmail);
  });

  it('filters the list by role', async () => {
    const res = await listUsers(adminToken, '?role=ADMIN').expect(200);

    const roles = res.body.data.map((u: { role: string }) => u.role);
    expect(roles.every((r: string) => r === 'ADMIN')).toBe(true);
    expect(res.body.data.some((u: { id: string }) => u.id === adminId)).toBe(
      true,
    );
  });

  it('returns a single user with recent orders and counts', async () => {
    const res = await request(app.getHttpServer())
      .get(`/api/admin/users/${customerId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect(res.body.id).toBe(customerId);
    expect(res.body.passwordHash).toBeUndefined();
    expect(Array.isArray(res.body.orders)).toBe(true);
    expect(res.body._count).toEqual(
      expect.objectContaining({ orders: expect.any(Number) }),
    );
  });

  it('404s a single-user lookup for an unknown id', async () => {
    await request(app.getHttpServer())
      .get('/api/admin/users/does-not-exist')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(404);
  });

  it('promotes a customer to admin', async () => {
    const res = await request(app.getHttpServer())
      .patch(`/api/admin/users/${customerId}/role`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ role: 'ADMIN' })
      .expect(200);

    expect(res.body.role).toBe('ADMIN');
    expect(res.body.passwordHash).toBeUndefined();
  });

  it('rejects an invalid role value', async () => {
    await request(app.getHttpServer())
      .patch(`/api/admin/users/${customerId}/role`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ role: 'SUPERUSER' })
      .expect(400);
  });

  it('forbids an admin from demoting themselves', async () => {
    await request(app.getHttpServer())
      .patch(`/api/admin/users/${adminId}/role`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ role: 'CUSTOMER' })
      .expect(403);
  });

  it('demotes another admin back to customer', async () => {
    const res = await request(app.getHttpServer())
      .patch(`/api/admin/users/${customerId}/role`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ role: 'CUSTOMER' })
      .expect(200);

    expect(res.body.role).toBe('CUSTOMER');
  });
});
