# E-Commerce Platform — Design Spec

- **Date:** 2026-06-27
- **Status:** Approved (active development)
- **Type:** Full-stack portfolio project

## 1. Goal

Build a complete, professional e-commerce platform that demonstrates end-to-end
capability across **mobile (Flutter)**, **backend (NestJS)**, and **admin (Next.js)**.
This is a portfolio piece — favour production-style patterns over MVP shortcuts.

## 2. Scope (full — nothing deferred)

**Customer (Flutter):** register/login, browse catalog, categories, search & filter,
product detail, cart, Stripe checkout, order history & tracking, profile & addresses,
**product reviews & ratings**, **favorites/wishlist**, **coupon codes**,
**multi-language (i18n)**, **push notifications** for order updates.

**Admin (Next.js):** admin login, dashboard (sales/orders/revenue with charts),
product CRUD (with image upload), category CRUD, order management (status flow),
coupon management, review moderation, user list.

**Out of scope (non-goals):** multi-vendor marketplace, real money capture
(Stripe runs in test mode), shipping-carrier integrations, tax engines.

## 3. Tech Stack

See [`CLAUDE.md`](../../CLAUDE.md) for pinned versions and rationale. Summary:
Flutter + Riverpod · NestJS + Prisma · PostgreSQL 18 · MinIO · Next.js 16 + React 19 ·
Stripe (test) · Node 24 LTS · Docker Compose.

**Version philosophy:** latest *stable* of every tool — deliberately avoiding
NestJS 12 (ESM breaking, Q3 2026), PostgreSQL 19 (beta), and Node 26 (not LTS yet).

## 4. Architecture

- **API (NestJS):** REST, modular (one module per domain), Prisma as data layer,
  JWT auth with role-based guards, DTO validation via `class-validator`, global error
  handling, Stripe webhooks, MinIO via the S3 SDK.
- **Admin (Next.js, App Router):** server components + TanStack Query for data,
  Tailwind for styling, talks to the API over REST with the admin JWT.
- **Mobile (Flutter):** Riverpod for state, Dio for HTTP (interceptors for auth +
  token refresh), go_router for navigation, freezed/json_serializable for models.
- **Data:** PostgreSQL via Prisma migrations. **Media:** MinIO bucket
  `product-images`, served via public-read URLs; admin uploads through the API.

## 5. Data Model (core entities)

| Entity | Key fields | Notes |
|--------|-----------|-------|
| User | email, passwordHash, name, role | role ∈ {CUSTOMER, ADMIN}, Argon2 hash |
| RefreshToken | userId, tokenHash, expiresAt | enables refresh-token revocation |
| Address | userId, fullName, phone, line1/2, city, district, postalCode, isDefault | |
| Category | name, slug, parentId | self-relation for nesting |
| Product | name, slug, description, price, compareAtPrice, currency, stock, isActive | |
| ProductImage | productId, url, sortOrder | URLs point to MinIO |
| ProductTranslation | productId, locale, name, description | i18n |
| CategoryTranslation | categoryId, locale, name | i18n |
| Cart / CartItem | userId / cartId, productId, quantity | server-side cart |
| Order | userId, status, subtotal, discountTotal, total, currency, addressId, couponId, stripePaymentIntentId | |
| OrderItem | orderId, productId, nameSnapshot, unitPriceSnapshot, quantity | price snapshotted at purchase |
| Review | productId, userId, rating(1-5), comment | one per user/product |
| Favorite | userId, productId | wishlist |
| Coupon | code, type, value, minSubtotal, maxUses, usedCount, expiresAt, isActive | type ∈ {PERCENTAGE, FIXED} |
| DeviceToken | userId, token, platform | FCM push targets |

**Order status flow:** `PENDING → PAID → PREPARING → SHIPPED → DELIVERED`
(plus `CANCELLED`, `REFUNDED`).

## 6. Cross-cutting concerns

- **Auth:** JWT access (short-lived) + refresh (rotating, revocable). Argon2 password
  hashing. Role guards (`@Roles('ADMIN')`).
- **Payments:** Stripe PaymentIntent created at checkout; order marked `PAID` via the
  Stripe **webhook** (not the client) to keep state authoritative.
- **Media:** images uploaded through the API to MinIO; only validated image types/size.
- **i18n:** translatable fields stored in `*Translation` tables; locale via
  `Accept-Language`. Flutter uses `flutter_localizations` + `intl` (ARB); admin uses
  `next-intl`.
- **Push:** Firebase Cloud Messaging; backend sends on order-status change. Requires a
  Firebase project (external setup — its own milestone).

## 7. Milestones

M0 repo/infra · M1 backend foundation · M2 auth · M3 catalog · M4 media · M5 cart+favorites ·
M6 orders+Stripe · M7 reviews · M8 coupons · M9 admin UI · M10 Flutter app · M11 i18n ·
M12 push · M13 polish (seed, tests, screenshots, CI). Each milestone ships independently.

## 8. Testing

- API: unit tests for services, e2e for critical flows (auth, checkout, webhook).
- Seed script for demo data (categories, products, admin user) to make the app
  demonstrable for the portfolio.
