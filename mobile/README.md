# Mobile — Flutter Customer App

The customer-facing storefront.

- **Stack:** Flutter 3.41+ · Riverpod 3 · Dio · go_router · flutter_stripe 13
- **Responsibilities:** auth, catalog browsing, search/filter, cart, Stripe checkout,
  orders & tracking, profile/addresses, reviews & ratings, favorites, i18n, push.

## Status

Milestone **M10** is in progress, slice by slice.

- [x] Foundation + auth — HTTP client with a self-refreshing JWT interceptor,
      secure token storage, auth-gated router, sign-in / sign-up screens
- [x] Catalog — product grid with infinite scroll, debounced search, category
      chips, price/sort filters, product detail with image gallery
- [x] Cart & favorites — server-truth cart with quantity steppers and badge,
      optimistic favorite hearts on cards and the detail screen
- [x] Stripe checkout — coupon quotes, order placement with reserved stock,
      payment sheet confirmation, retryable pending payments
- [x] Orders & tracking — order history with pull-to-refresh, detail view
      with a fulfilment timeline and the totals exactly as charged
- [ ] Profile & addresses
- [ ] Reviews & ratings

## Layout

```
lib/
├── core/           # config, HTTP client, secure storage, router, theme
├── features/       # one folder per feature: domain / data / application / presentation
├── shared/         # cross-feature helpers (validation, formatting)
├── app.dart        # MaterialApp.router
└── main.dart       # ProviderScope entry point
```

State lives in Riverpod providers declared next to the class they expose. No
code generation: providers and `fromJson` factories are written by hand, because
`riverpod_lint` / `riverpod_generator` still pin `riverpod_annotation` 2.x and
cannot resolve against Riverpod 3.

Riverpod 3's automatic provider retry is disabled at the root `ProviderScope`:
every failing surface has explicit retry UX instead (retry buttons,
pull-to-refresh), and background retries would re-hammer a struggling API.

## Running

The app talks to the NestJS API, so bring that up first (see `../api`).

```bash
flutter pub get
flutter run
```

The default API base URL is `http://10.0.2.2:3000/api` on the Android emulator
(which maps the host machine to that address) and `http://localhost:3000/api`
everywhere else. Point it at a real host — a physical device on your LAN, say —
without touching source:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/api
```

Checkout needs the Stripe *publishable* key (the secret key stays on the API):

```bash
flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...
```

Without it the app still runs; paying fails with a clear configuration
message instead of opening the payment sheet.

## Checks

```bash
flutter analyze
flutter test
```
