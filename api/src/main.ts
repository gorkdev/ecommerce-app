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
  const port = config.get<number>('API_PORT') ?? 3000;
  await app.listen(port);
}

void bootstrap();
