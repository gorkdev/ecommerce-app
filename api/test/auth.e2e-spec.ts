import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

describe('Auth (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  const email = 'e2e-auth@example.com';
  const password = 'supersecret1';

  let accessToken: string;
  let refreshToken: string;

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
    await prisma.user.deleteMany({ where: { email } });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email } });
    await app.close();
  });

  it('registers a new user', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email, password, name: 'E2E Tester' })
      .expect(201);

    expect(res.body.accessToken).toBeDefined();
    expect(res.body.refreshToken).toBeDefined();
    expect(res.body.user.email).toBe(email);
    expect(res.body.user.passwordHash).toBeUndefined();
  });

  it('rejects duplicate registration', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email, password, name: 'E2E Tester' })
      .expect(409);
  });

  it('rejects invalid input via validation', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email: 'not-an-email', password: '123', name: 'x' })
      .expect(400);
  });

  it('rejects login with a wrong password', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email, password: 'wrongpass1' })
      .expect(401);
  });

  it('logs in with valid credentials', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email, password })
      .expect(200);

    accessToken = res.body.accessToken;
    refreshToken = res.body.refreshToken;
    expect(accessToken).toBeDefined();
    expect(refreshToken).toBeDefined();
  });

  it('blocks /me without a token', async () => {
    await request(app.getHttpServer()).get('/api/auth/me').expect(401);
  });

  it('returns the profile for an authenticated user', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);

    expect(res.body.email).toBe(email);
    expect(res.body.passwordHash).toBeUndefined();
  });

  it('rotates tokens on refresh and invalidates the old one', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/auth/refresh')
      .send({ refreshToken })
      .expect(200);

    const newRefresh = res.body.refreshToken as string;
    expect(res.body.accessToken).toBeDefined();
    expect(newRefresh).toBeDefined();

    // Rotation: the previous refresh token must be rejected.
    await request(app.getHttpServer())
      .post('/api/auth/refresh')
      .send({ refreshToken })
      .expect(401);

    refreshToken = newRefresh;
  });

  it('logs out and revokes the refresh token', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/logout')
      .send({ refreshToken })
      .expect(204);

    await request(app.getHttpServer())
      .post('/api/auth/refresh')
      .send({ refreshToken })
      .expect(401);
  });
});
