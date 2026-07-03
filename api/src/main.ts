import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';

async function bootstrap() {
  // rawBody: keep the unparsed payload so the Stripe webhook can verify
  // the request signature against the exact bytes Stripe signed.
  const app = await NestFactory.create(AppModule, { rawBody: true });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );
  app.setGlobalPrefix('api');

  const config = app.get(ConfigService);

  // Allow the browser-based admin (and any configured front-ends) to call the
  // API cross-origin. Origins are comma-separated in CORS_ORIGIN; the admin dev
  // server runs on :3001 by default.
  const corsOrigin = config.get<string>('CORS_ORIGIN') ?? 'http://localhost:3001';
  app.enableCors({
    origin: corsOrigin.split(',').map((o) => o.trim()),
    credentials: true,
  });

  const port = config.get<number>('API_PORT') ?? 3000;
  await app.listen(port);
}

void bootstrap();
