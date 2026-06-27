# CLAUDE.md — Project Guide

Context for any AI/automation session working in this repository. Read this first.

## What this is

A full-stack, **portfolio-grade** e-commerce platform. The goal is not an MVP but a
complete, professional product showcasing mobile + backend + admin together.
**Quality and professional patterns over shortcuts.**

## Tech stack (pinned — latest *stable*, no betas)

| Area | Choice | Version | Why this version |
|------|--------|---------|------------------|
| Mobile | Flutter + Riverpod | Flutter 3.41.x (installed) · Riverpod 3 | Latest installed stable; 3.44 available via `flutter upgrade` |
| Mobile payments | flutter_stripe | 13.0.0 | Current stable |
| Backend | NestJS | 11.1.x | v12 (Q3 2026) brings ESM breaking changes → stay on stable 11 |
| ORM | Prisma | 7.8.x | Rust-free runtime, Postgres 18 support |
| Database | PostgreSQL | 18 | 19 is still beta → newest stable is 18 |
| Object storage | MinIO | latest image | S3-compatible |
| Admin | Next.js + React | 16.2.x + React 19 | Turbopack default, React Compiler stable |
| Payments (server) | stripe-node | 22.x | Matches flutter_stripe API version |
| Runtime | Node.js | 24 LTS | 26 is "Current" not LTS yet → 24 LTS for prod |

## Repository layout

- `api/` — NestJS + Prisma REST API (source of truth for the data model)
- `admin/` — Next.js admin dashboard
- `mobile/` — Flutter customer app
- `docker-compose.yml` — Postgres + MinIO (app services added later)

## Full scope (nothing deferred)

Auth · catalog (categories/products) · search & filtering · cart · Stripe checkout ·
orders & order tracking · profile & addresses · **product reviews & ratings** ·
**favorites/wishlist** · **coupons/discounts** · **i18n (multi-language)** ·
**push notifications (FCM)**. Admin covers dashboard, product/category CRUD, order
management, and users.

## Working conventions

- **Step by step.** Work milestone by milestone (see README roadmap). Do not try to
  build everything in one pass. Each milestone = its own focused commit(s).
- **Docker-first.** Backing services run in containers; prefer reproducible setups.
- **Professional patterns.** DTO validation, layered modules, typed clients,
  migrations (never manual SQL), env-based config, no secrets in git.
- **Test every feature.** After implementing a feature, write detailed tests for it
  (unit tests for services, e2e tests for endpoints/flows). A feature is not "done"
  until its tests are written and passing.
- **Commit + push per feature.** As soon as a feature is complete and its tests pass,
  make a Conventional Commit and push it immediately. Do not batch unrelated features
  into a single commit.
- **Docs.** Keep this guide in sync when decisions change. (The detailed design
  spec is kept developer-local under `docs/specs/`, which is gitignored — not part
  of the public portfolio repo.)

## Commit & push rules

- Commit messages **in English**, **Conventional Commits** (`feat:`, `fix:`,
  `chore:`, `refactor:`, `docs:`, …) with a scope where useful (e.g. `feat(api): …`).
- Short imperative subject (~50 chars), blank line, then a multi-line bullet body
  (the *what* and the *why*).
- **Never** add `Co-Authored-By` or any "Generated with …" / attribution trailer.

## Common commands

```bash
docker compose up -d            # start postgres + minio
docker compose down             # stop
# api (once scaffolded):
cd api && npm install && npx prisma migrate dev && npm run start:dev
```
