# API — NestJS + Prisma

REST API for the e-commerce platform.

- **Stack:** NestJS 11 · Prisma 7 · PostgreSQL 18 · Node 24 LTS
- **Responsibilities:** auth (JWT), catalog, cart, orders, Stripe payments/webhooks,
  reviews, coupons, media (MinIO), i18n, push (FCM).

## Local setup

```bash
cp ../.env.example ../.env      # configure once at repo root
docker compose up -d            # (from repo root) start postgres + minio
npm install
npx prisma migrate dev          # apply migrations
npm run start:dev               # http://localhost:3000
```

Module-by-module functionality lands per the roadmap in the root README.
