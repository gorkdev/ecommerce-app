import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

// 1x1 transparent PNG.
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  'base64',
);

describe('Media (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  const adminEmail = 'e2e-media-admin@example.com';
  const customerEmail = 'e2e-media-customer@example.com';
  const password = 'supersecret1';
  const categorySlug = 'e2e-media-cat';
  const productSlug = 'e2e-media-product';

  let adminToken: string;
  let customerToken: string;
  let productId: string;
  let categoryId: string;

  const cleanup = async () => {
    await prisma.product.deleteMany({ where: { slug: productSlug } });
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

    await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email: adminEmail, password, name: 'Admin' })
      .expect(201);
    await prisma.user.update({
      where: { email: adminEmail },
      data: { role: 'ADMIN' },
    });
    adminToken = (
      await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: adminEmail, password })
        .expect(200)
    ).body.accessToken;

    customerToken = (
      await request(app.getHttpServer())
        .post('/api/auth/register')
        .send({ email: customerEmail, password, name: 'Customer' })
        .expect(201)
    ).body.accessToken;

    categoryId = (
      await request(app.getHttpServer())
        .post('/api/categories')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ name: 'Media Cat', slug: categorySlug })
        .expect(201)
    ).body.id;

    productId = (
      await request(app.getHttpServer())
        .post('/api/products')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          name: 'Media Product',
          slug: productSlug,
          description: 'Has images',
          price: 10,
          categoryId,
        })
        .expect(201)
    ).body.id;
  });

  afterAll(async () => {
    await cleanup();
    await app.close();
  });

  let key: string;
  let publicUrl: string;
  let imageId: string;

  it('forbids a customer from requesting an upload URL', async () => {
    await request(app.getHttpServer())
      .post(`/api/products/${productId}/images/presign`)
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ contentType: 'image/png' })
      .expect(403);
  });

  it('rejects an unsupported content type', async () => {
    await request(app.getHttpServer())
      .post(`/api/products/${productId}/images/presign`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ contentType: 'application/pdf' })
      .expect(400);
  });

  it('issues a presigned upload URL to an admin', async () => {
    const res = await request(app.getHttpServer())
      .post(`/api/products/${productId}/images/presign`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ contentType: 'image/png' })
      .expect(201);

    key = res.body.key;
    publicUrl = res.body.publicUrl;
    expect(key.startsWith(`products/${productId}/`)).toBe(true);
    expect(res.body.uploadUrl).toContain(key);
  });

  it('uploads the file directly to MinIO via the presigned URL', async () => {
    const presign = await request(app.getHttpServer())
      .post(`/api/products/${productId}/images/presign`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ contentType: 'image/png' })
      .expect(201);

    const putRes = await fetch(presign.body.uploadUrl as string, {
      method: 'PUT',
      headers: { 'Content-Type': 'image/png' },
      body: PNG,
    });
    expect(putRes.ok).toBe(true);

    // Re-point our working key/url to the actually-uploaded object.
    key = presign.body.key;
    publicUrl = presign.body.publicUrl;

    const getRes = await fetch(publicUrl);
    expect(getRes.status).toBe(200);
  });

  it('attaches the uploaded image to the product', async () => {
    const res = await request(app.getHttpServer())
      .post(`/api/products/${productId}/images`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ key })
      .expect(201);

    imageId = res.body.id;
    expect(res.body.url).toBe(publicUrl);
  });

  it('rejects a key from another product namespace', async () => {
    await request(app.getHttpServer())
      .post(`/api/products/${productId}/images`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ key: 'products/someone-else/x.png' })
      .expect(400);
  });

  it('exposes the image in the public product detail', async () => {
    const res = await request(app.getHttpServer())
      .get(`/api/products/${productSlug}`)
      .expect(200);

    expect(
      res.body.images.some((img: { url: string }) => img.url === publicUrl),
    ).toBe(true);
  });

  it('deletes the image from storage and the database', async () => {
    await request(app.getHttpServer())
      .delete(`/api/products/${productId}/images/${imageId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(204);

    const getRes = await fetch(publicUrl);
    expect(getRes.status).not.toBe(200);
  });
});
