import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

describe('Reviews (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  const adminEmail = 'e2e-review-admin@example.com';
  const buyerEmail = 'e2e-review-buyer@example.com';
  const strangerEmail = 'e2e-review-stranger@example.com';
  const emails = [adminEmail, buyerEmail, strangerEmail];
  const password = 'supersecret1';

  const categorySlug = 'e2e-review-cat';
  const productSlug = 'e2e-review-product';

  let adminToken: string;
  let buyerToken: string;
  let strangerToken: string;
  let productId: string;

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

  const reviewsUrl = () => `/api/products/${productId}/reviews`;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
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

    const buyerReg = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email: buyerEmail, password, name: 'Buyer' })
      .expect(201);
    buyerToken = buyerReg.body.accessToken;

    const strangerReg = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email: strangerEmail, password, name: 'Stranger' })
      .expect(201);
    strangerToken = strangerReg.body.accessToken;

    const category = await request(app.getHttpServer())
      .post('/api/categories')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ name: 'Reviews', slug: categorySlug })
      .expect(201);

    const product = await request(app.getHttpServer())
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: 'Review Product',
        slug: productSlug,
        description: 'For review e2e',
        price: 25,
        stock: 5,
        categoryId: category.body.id,
      })
      .expect(201);
    productId = product.body.id;

    // The buyer has a completed (PAID) purchase of the product, which is what
    // unlocks the ability to review it. The stranger has no such order.
    const buyer = await prisma.user.findUnique({
      where: { email: buyerEmail },
    });
    await prisma.order.create({
      data: {
        userId: buyer!.id,
        status: 'PAID',
        subtotal: '25',
        total: '25',
        currency: 'TRY',
        items: {
          create: [
            {
              productId,
              nameSnapshot: 'Review Product',
              priceSnapshot: '25',
              quantity: 1,
            },
          ],
        },
      },
    });
  });

  afterAll(async () => {
    await cleanup();
    await app.close();
  });

  let reviewId: string;

  it('serves an empty public summary before any review', async () => {
    const res = await request(app.getHttpServer())
      .get(reviewsUrl())
      .expect(200);

    expect(res.body.items).toHaveLength(0);
    expect(res.body.summary).toEqual({
      average: 0,
      count: 0,
      distribution: { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 },
    });
  });

  it('requires auth to submit a review', async () => {
    await request(app.getHttpServer())
      .post(reviewsUrl())
      .send({ rating: 5 })
      .expect(401);
  });

  it('rejects an out-of-range rating', async () => {
    await request(app.getHttpServer())
      .post(reviewsUrl())
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ rating: 6 })
      .expect(400);
    await request(app.getHttpServer())
      .post(reviewsUrl())
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ rating: 0 })
      .expect(400);
  });

  it('forbids a customer who never purchased the product', async () => {
    await request(app.getHttpServer())
      .post(reviewsUrl())
      .set('Authorization', `Bearer ${strangerToken}`)
      .send({ rating: 5, comment: 'Never bought it' })
      .expect(403);
  });

  it('lets a verified buyer post a review', async () => {
    const res = await request(app.getHttpServer())
      .post(reviewsUrl())
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ rating: 5, comment: 'Great product' })
      .expect(201);

    reviewId = res.body.id;
    expect(res.body.rating).toBe(5);
    expect(res.body.comment).toBe('Great product');
    expect(res.body.user.name).toBe('Buyer');
    expect(res.body.user.email).toBeUndefined(); // email never exposed publicly
  });

  it('reflects the review in the public summary', async () => {
    const res = await request(app.getHttpServer())
      .get(reviewsUrl())
      .expect(200);

    expect(res.body.items).toHaveLength(1);
    expect(res.body.summary.average).toBe(5);
    expect(res.body.summary.count).toBe(1);
    expect(res.body.summary.distribution['5']).toBe(1);
  });

  it('returns the buyer own review via /me', async () => {
    const res = await request(app.getHttpServer())
      .get(`${reviewsUrl()}/me`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .expect(200);

    expect(res.body.id).toBe(reviewId);
    expect(res.body.rating).toBe(5);
  });

  it('upserts on a second submit instead of duplicating', async () => {
    const res = await request(app.getHttpServer())
      .post(reviewsUrl())
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ rating: 3, comment: 'Changed my mind' })
      .expect(201);

    expect(res.body.id).toBe(reviewId); // same row
    expect(res.body.rating).toBe(3);

    const list = await request(app.getHttpServer())
      .get(reviewsUrl())
      .expect(200);
    expect(list.body.items).toHaveLength(1);
    expect(list.body.summary.average).toBe(3);
  });

  it('forbids a non-admin from the moderation list', async () => {
    await request(app.getHttpServer())
      .get('/api/admin/reviews')
      .set('Authorization', `Bearer ${buyerToken}`)
      .expect(403);
  });

  it('lets an admin list and filter reviews', async () => {
    const res = await request(app.getHttpServer())
      .get(`/api/admin/reviews?productId=${productId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect(res.body.data.some((r: { id: string }) => r.id === reviewId)).toBe(
      true,
    );
    expect(res.body.meta.total).toBeGreaterThanOrEqual(1);
  });

  it('lets an admin delete (moderate) any review', async () => {
    await request(app.getHttpServer())
      .delete(`/api/admin/reviews/${reviewId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(204);

    const res = await request(app.getHttpServer())
      .get(reviewsUrl())
      .expect(200);
    expect(res.body.items).toHaveLength(0);
    expect(res.body.summary.count).toBe(0);
  });

  it('lets the buyer delete their own review', async () => {
    await request(app.getHttpServer())
      .post(reviewsUrl())
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ rating: 4 })
      .expect(201);

    await request(app.getHttpServer())
      .delete(`${reviewsUrl()}/me`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .expect(204);

    const me = await request(app.getHttpServer())
      .get(`${reviewsUrl()}/me`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .expect(200);
    expect(me.body.rating).toBeUndefined();
  });

  it('404s when deleting a review that no longer exists', async () => {
    await request(app.getHttpServer())
      .delete(`${reviewsUrl()}/me`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .expect(404);
  });
});
