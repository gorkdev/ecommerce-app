import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

describe('Addresses (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  const ownerEmail = 'e2e-addr-owner@example.com';
  const strangerEmail = 'e2e-addr-stranger@example.com';
  const password = 'supersecret1';

  let ownerToken: string;
  let strangerToken: string;

  const validAddress = {
    fullName: 'Ada Lovelace',
    phone: '+905551112233',
    line1: 'Analytical Engine St. 42',
    city: 'Istanbul',
    district: 'Kadikoy',
    postalCode: '34710',
  };

  const cleanup = async () => {
    // Deleting the users cascades their addresses.
    await prisma.user.deleteMany({
      where: { email: { in: [ownerEmail, strangerEmail] } },
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

    const owner = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email: ownerEmail, password, name: 'Owner' })
      .expect(201);
    ownerToken = owner.body.accessToken;

    const stranger = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email: strangerEmail, password, name: 'Stranger' })
      .expect(201);
    strangerToken = stranger.body.accessToken;
  });

  afterAll(async () => {
    await cleanup();
    await app.close();
  });

  it('requires authentication', async () => {
    await request(app.getHttpServer()).get('/api/addresses').expect(401);
  });

  it('starts with an empty list', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/addresses')
      .set('Authorization', `Bearer ${ownerToken}`)
      .expect(200);
    expect(res.body).toEqual([]);
  });

  it('rejects an invalid payload', async () => {
    await request(app.getHttpServer())
      .post('/api/addresses')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ ...validAddress, fullName: 'A' })
      .expect(400);
  });

  let firstId: string;
  let secondId: string;

  it('makes the first address the default even unasked', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/addresses')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ ...validAddress, isDefault: false })
      .expect(201);
    firstId = res.body.id;
    expect(res.body.isDefault).toBe(true);
    expect(res.body.country).toBe('TR');
  });

  it('moves the default when a second address claims it', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/addresses')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        ...validAddress,
        line1: 'Second Home 7',
        city: 'Ankara',
        district: 'Cankaya',
        postalCode: '06690',
        isDefault: true,
      })
      .expect(201);
    secondId = res.body.id;
    expect(res.body.isDefault).toBe(true);

    const list = await request(app.getHttpServer())
      .get('/api/addresses')
      .set('Authorization', `Bearer ${ownerToken}`)
      .expect(200);
    expect(list.body).toHaveLength(2);
    // Default first, and only one of them.
    expect(list.body[0].id).toBe(secondId);
    expect(list.body.filter((a: { isDefault: boolean }) => a.isDefault)).toHaveLength(1);
  });

  it('refuses to strip the default flag directly', async () => {
    const res = await request(app.getHttpServer())
      .patch(`/api/addresses/${secondId}`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ isDefault: false })
      .expect(400);
    expect(res.body.message).toBe('Set another address as the default first');
  });

  it('moves the default back through a patch', async () => {
    const res = await request(app.getHttpServer())
      .patch(`/api/addresses/${firstId}`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ isDefault: true, city: 'Izmir' })
      .expect(200);
    expect(res.body.isDefault).toBe(true);
    expect(res.body.city).toBe('Izmir');
  });

  it('hides other users addresses from patch and delete', async () => {
    await request(app.getHttpServer())
      .patch(`/api/addresses/${firstId}`)
      .set('Authorization', `Bearer ${strangerToken}`)
      .send({ city: 'Nope' })
      .expect(404);
    await request(app.getHttpServer())
      .delete(`/api/addresses/${firstId}`)
      .set('Authorization', `Bearer ${strangerToken}`)
      .expect(404);
  });

  it('promotes the remaining address when the default is deleted', async () => {
    await request(app.getHttpServer())
      .delete(`/api/addresses/${firstId}`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .expect(204);

    const list = await request(app.getHttpServer())
      .get('/api/addresses')
      .set('Authorization', `Bearer ${ownerToken}`)
      .expect(200);
    expect(list.body).toHaveLength(1);
    expect(list.body[0].id).toBe(secondId);
    expect(list.body[0].isDefault).toBe(true);
  });
});
