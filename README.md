# 🛒 E-Commerce Platform

A full-stack, production-style e-commerce platform built as a portfolio project.
It pairs a **Flutter** mobile storefront with a **NestJS** API, a **Next.js** admin
dashboard, **PostgreSQL** + **MinIO** for data and media, and **Stripe** for payments —
all orchestrated with **Docker Compose**.

> **Status:** 🚧 In active development — built milestone by milestone.

## Architecture

```
        ┌──────────────┐          ┌──────────────┐
        │  Flutter app │          │   Next.js    │
        │  (customer)  │          │  admin panel │
        └──────┬───────┘          └──────┬───────┘
               │      REST / JWT         │
               └────────────┬────────────┘
                            ▼
                   ┌──────────────────┐
                   │    NestJS API    │
                   │  (REST · JWT)    │
                   └───┬──────────┬───┘
                       │          │
              ┌────────▼───┐  ┌───▼──────────┐
              │ PostgreSQL │  │    MinIO     │
              │  (Prisma)  │  │ (S3 images)  │
              └────────────┘  └──────────────┘
                       │
                ┌──────▼──────┐
                │   Stripe    │  (test mode · webhooks)
                └─────────────┘
```

## Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Mobile (customer) | Flutter · Riverpod · Dio · go_router | Flutter 3.41+ · Riverpod 3 |
| Backend API | NestJS · Prisma | NestJS 11 · Prisma 7 |
| Database | PostgreSQL | 18 |
| Object storage | MinIO (S3-compatible) | latest |
| Admin panel | Next.js · React · TanStack Query · Tailwind | Next 16 · React 19 |
| Payments | Stripe (test mode) | stripe-node 22 · flutter_stripe 13 |
| Runtime | Node.js | 24 LTS |
| Orchestration | Docker Compose | — |

> Version choices are deliberately the **latest *stable*** of each tool (no betas/RCs).
> See [`docs/specs`](docs/specs) for the rationale.

## Repository Structure

```
ecommerce-app/
├── api/                # NestJS + Prisma REST API
├── admin/              # Next.js admin dashboard
├── mobile/             # Flutter customer app
├── docs/specs/         # Design specs
├── docker-compose.yml  # postgres + minio (infra)
└── .env.example        # configuration template
```

## Getting Started

```bash
# 1. Copy environment template
cp .env.example .env

# 2. Bring up the infrastructure (PostgreSQL + MinIO)
docker compose up -d

#    MinIO console:  http://localhost:9001  (minioadmin / minioadmin)
#    PostgreSQL:     localhost:5432
```

Per-service setup (api / admin / mobile) is documented in each subfolder's README
as those milestones land.

## Roadmap

- [x] **M0** — Repo, docs, infra skeleton (Postgres + MinIO)
- [ ] **M1** — Backend foundation (NestJS skeleton, Prisma schema, migrations)
- [ ] **M2** — Auth (JWT access/refresh, roles, guards)
- [ ] **M3** — Catalog (categories + products: admin CRUD, public list/detail)
- [ ] **M4** — Media (MinIO uploads, presigned URLs)
- [ ] **M5** — Cart + Favorites
- [ ] **M6** — Orders + Stripe checkout + webhooks
- [ ] **M7** — Reviews & ratings
- [ ] **M8** — Coupons / discounts
- [ ] **M9** — Admin panel UI (dashboard, products, orders, users)
- [ ] **M10** — Flutter app (full customer flow)
- [ ] **M11** — Internationalization (i18n)
- [ ] **M12** — Push notifications (FCM)
- [ ] **M13** — Polish (seed data, tests, screenshots, CI)

## License

MIT
