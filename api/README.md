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

## Demo data (seed)

```bash
npm run prisma:seed             # or: npx prisma db seed
```

Populates the database with a browsable store: a category tree, 18 products
(with generated placeholder images uploaded straight to MinIO), coupons in
every state, and orders/reviews/favorites spread across four customers so the
admin dashboard, the order pipeline and the product rating summaries all have
real data. The script is idempotent — rerun it anytime to restore the demo
state; it never duplicates rows.

| Account | Email | Password |
|---------|-------|----------|
| Admin (dashboard) | `admin@example.com` | `Admin123!` |
| Customer (mobile) | `ada@example.com` | `Customer123!` |
| Customer (mobile) | `deniz@example.com` | `Customer123!` |

If MinIO is not running the seed still completes — products just render
without images.

## Push notifications (FCM)

Order lifecycle changes (payment confirmed, preparing, shipped, delivered,
cancelled, refunded) are pushed to the customer's devices through Firebase
Cloud Messaging. The mobile app registers its device token via
`POST /notifications/tokens` (and removes it on sign-out); each token carries
the language it wants notifications in, so the copy is rendered server-side
in English or Turkish. Tokens Firebase reports as dead are pruned
automatically, and a push failure never fails the request that triggered it.

Setup is optional — without it the API runs normally and skips pushes:

1. Create a Firebase project and generate a service-account key
   (Project settings → Service accounts → Generate new private key).
2. Save the JSON next to the API (it is gitignored) and point
   `FIREBASE_SERVICE_ACCOUNT` at it in `.env`.
