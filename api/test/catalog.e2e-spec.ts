import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

describe('Catalog (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  const adminEmail = 'e2e-catalog-admin@example.com';
  const customerEmail = 'e2e-catalog-customer@example.com';
  const password = 'supersecret1';

  const categorySlug = 'e2e-shoes';
  const productSlug = 'e2e-running-shoes';

  let adminToken: string;
  let customerToken: string;
  let categoryId: string;
  let productId: string;

  const cleanup = async () => {
    await prisma.product.deleteMany({
      where: { slug: { in: [productSlug, 'e2e-running-shoes-2'] } },
    });
    await prisma.category.deleteMany({ where: { slug: categorySlug } });
    await prisma.user.deleteMany({
      where: { email: { in: [adminEmail, customerEmail] } },
    });
  };

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

    // Admin: register, then promote to ADMIN, then log in.
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

    // Customer: a regular user that must be forbidden from admin routes.
    const customerReg = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email: customerEmail, password, name: 'Customer' })
      .expect(201);
    customerToken = customerReg.body.accessToken;
  });

  afterAll(async () => {
    await cleanup();
    await app.close();
  });

  // ---- Authorization ----

  it('blocks anonymous category creation', async () => {
    await request(app.getHttpServer())
      .post('/api/categories')
      .send({ name: 'Hacker' })
      .expect(401);
  });

  it('forbids a customer from creating a category', async () => {
    await request(app.getHttpServer())
      .post('/api/categories')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ name: 'Hacker' })
      .expect(403);
  });

  // ---- Category CRUD (admin) ----

  it('lets an admin create a category', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/categories')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ name: 'Shoes', slug: categorySlug })
      .expect(201);

    categoryId = res.body.id;
    expect(res.body.slug).toBe(categorySlug);
  });

  it('rejects a duplicate category slug', async () => {
    await request(app.getHttpServer())
      .post('/api/categories')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ name: 'Shoes Again', slug: categorySlug })
      .expect(409);
  });

  // ---- Product CRUD (admin) ----

  it('lets an admin create a product', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: 'Running Shoes',
        slug: productSlug,
        description: 'Lightweight running shoes',
        price: 49.9,
        stock: 5,
        categoryId,
      })
      .expect(201);

    productId = res.body.id;
    expect(res.body.slug).toBe(productSlug);
    expect(Number(res.body.price)).toBe(49.9);
    expect(res.body.category.slug).toBe(categorySlug);
  });

  it('rejects a product for an unknown category', async () => {
    await request(app.getHttpServer())
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: 'Orphan',
        slug: 'e2e-running-shoes-2',
        description: 'x',
        price: 10,
        categoryId: 'does-not-exist',
      })
      .expect(404);
  });

  it('validates product input', async () => {
    await request(app.getHttpServer())
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ name: 'x', price: -1, categoryId })
      .expect(400);
  });

  // ---- Public read ----

  it('lists the product publicly with pagination meta', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/products')
      .expect(200);

    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.meta).toEqual(
      expect.objectContaining({ page: 1, limit: 20 }),
    );
    expect(res.body.data.some((p: { slug: string }) => p.slug === productSlug)).toBe(
      true,
    );
  });

  it('filters products by search term', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/products')
      .query({ search: 'running' })
      .expect(200);

    expect(
      res.body.data.every((p: { slug: string }) =>
        p.slug.includes('running'),
      ),
    ).toBe(true);
  });

  it('returns a product by slug', async () => {
    const res = await request(app.getHttpServer())
      .get(`/api/products/${productSlug}`)
      .expect(200);

    expect(res.body.id).toBe(productId);
    expect(res.body.category.slug).toBe(categorySlug);
  });

  it('404s for an unknown product slug', async () => {
    await request(app.getHttpServer())
      .get('/api/products/no-such-product')
      .expect(404);
  });

  it('exposes the category in the public tree', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/categories')
      .expect(200);

    expect(
      res.body.some((c: { slug: string }) => c.slug === categorySlug),
    ).toBe(true);
  });

  // ---- Update / delete ----

  it('lets an admin update a product', async () => {
    const res = await request(app.getHttpServer())
      .patch(`/api/products/${productId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ price: 59.5, stock: 12 })
      .expect(200);

    expect(Number(res.body.price)).toBe(59.5);
    expect(res.body.stock).toBe(12);
  });

  it('refuses to delete a category that still has products', async () => {
    await request(app.getHttpServer())
      .delete(`/api/categories/${categoryId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(409);
  });

  it('lets an admin delete a product', async () => {
    await request(app.getHttpServer())
      .delete(`/api/products/${productId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(204);

    await request(app.getHttpServer())
      .get(`/api/products/${productSlug}`)
      .expect(404);
  });

  it('lets an admin delete the now-empty category', async () => {
    await request(app.getHttpServer())
      .delete(`/api/categories/${categoryId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(204);
  });
});
