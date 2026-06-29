import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

describe('Cart + Favorites (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  const adminEmail = 'e2e-m5-admin@example.com';
  const customerEmail = 'e2e-m5-customer@example.com';
  const password = 'supersecret1';

  const categorySlug = 'e2e-m5-cat';
  const productSlug = 'e2e-m5-product';

  let adminToken: string;
  let customerToken: string;
  let categoryId: string;
  let productId: string;

  const cleanup = async () => {
    // Deleting the users cascades their carts (+ items) and favorites,
    // which in turn frees the product to be deleted.
    await prisma.user.deleteMany({
      where: { email: { in: [adminEmail, customerEmail] } },
    });
    await prisma.product.deleteMany({ where: { slug: productSlug } });
    await prisma.category.deleteMany({ where: { slug: categorySlug } });
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

    // Admin to seed the catalog.
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

    // Customer who owns the cart / wishlist under test.
    const customerReg = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email: customerEmail, password, name: 'Customer' })
      .expect(201);
    customerToken = customerReg.body.accessToken;

    const category = await request(app.getHttpServer())
      .post('/api/categories')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ name: 'M5', slug: categorySlug })
      .expect(201);
    categoryId = category.body.id;

    const product = await request(app.getHttpServer())
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: 'M5 Product',
        slug: productSlug,
        description: 'For cart + favorites e2e',
        price: 25,
        stock: 5,
        categoryId,
      })
      .expect(201);
    productId = product.body.id;
  });

  afterAll(async () => {
    await cleanup();
    await app.close();
  });

  // ---- Cart ----

  it('requires auth to read the cart', async () => {
    await request(app.getHttpServer()).get('/api/cart').expect(401);
  });

  it('starts with an empty cart', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/cart')
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(200);

    expect(res.body.items).toEqual([]);
    expect(res.body.summary).toEqual(
      expect.objectContaining({ itemCount: 0, subtotal: '0.00' }),
    );
  });

  it('adds an item and reflects it in the summary', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/cart/items')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ productId, quantity: 2 })
      .expect(201);

    expect(res.body.summary.itemCount).toBe(2);
    expect(res.body.summary.subtotal).toBe('50.00');
    expect(res.body.items[0].product.id).toBe(productId);
  });

  it('accumulates quantity when the same product is added again', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/cart/items')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ productId, quantity: 1 })
      .expect(201);

    expect(res.body.items).toHaveLength(1);
    expect(res.body.summary.itemCount).toBe(3);
  });

  it('rejects adding beyond available stock', async () => {
    await request(app.getHttpServer())
      .post('/api/cart/items')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ productId, quantity: 99 })
      .expect(400);
  });

  it('404s when adding an unknown product', async () => {
    await request(app.getHttpServer())
      .post('/api/cart/items')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ productId: 'does-not-exist', quantity: 1 })
      .expect(404);
  });

  it('validates the add-item payload', async () => {
    await request(app.getHttpServer())
      .post('/api/cart/items')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ productId, quantity: 0 })
      .expect(400);
  });

  it('updates a line quantity', async () => {
    const res = await request(app.getHttpServer())
      .patch(`/api/cart/items/${productId}`)
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ quantity: 4 })
      .expect(200);

    expect(res.body.summary.itemCount).toBe(4);
    expect(res.body.summary.subtotal).toBe('100.00');
  });

  it('rejects an update beyond stock', async () => {
    await request(app.getHttpServer())
      .patch(`/api/cart/items/${productId}`)
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ quantity: 6 })
      .expect(400);
  });

  it('404s when updating a product that is not in the cart', async () => {
    await request(app.getHttpServer())
      .patch('/api/cart/items/not-in-cart')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ quantity: 1 })
      .expect(404);
  });

  it('removes a line', async () => {
    const res = await request(app.getHttpServer())
      .delete(`/api/cart/items/${productId}`)
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(200);

    expect(res.body.items).toEqual([]);
    expect(res.body.summary.itemCount).toBe(0);
  });

  it('clears the cart', async () => {
    await request(app.getHttpServer())
      .post('/api/cart/items')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ productId, quantity: 1 })
      .expect(201);

    const res = await request(app.getHttpServer())
      .delete('/api/cart')
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(200);

    expect(res.body.items).toEqual([]);
  });

  // ---- Favorites ----

  it('requires auth to read favorites', async () => {
    await request(app.getHttpServer()).get('/api/favorites').expect(401);
  });

  it('adds a favorite', async () => {
    const res = await request(app.getHttpServer())
      .post(`/api/favorites/${productId}`)
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(201);

    expect(res.body).toHaveLength(1);
    expect(res.body[0].product.id).toBe(productId);
  });

  it('is idempotent when favouriting the same product twice', async () => {
    const res = await request(app.getHttpServer())
      .post(`/api/favorites/${productId}`)
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(201);

    expect(res.body).toHaveLength(1);
  });

  it('404s when favouriting an unknown product', async () => {
    await request(app.getHttpServer())
      .post('/api/favorites/does-not-exist')
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(404);
  });

  it('lists favorites', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/favorites')
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(200);

    expect(res.body.some((f: { product: { id: string } }) => f.product.id === productId)).toBe(
      true,
    );
  });

  it('removes a favorite', async () => {
    await request(app.getHttpServer())
      .delete(`/api/favorites/${productId}`)
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(204);
  });

  it('404s when removing a favorite that is not saved', async () => {
    await request(app.getHttpServer())
      .delete(`/api/favorites/${productId}`)
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(404);
  });
});
