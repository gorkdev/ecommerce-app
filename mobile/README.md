# Mobile — Flutter Customer App

The customer-facing storefront.

- **Stack:** Flutter 3.41+ · Riverpod 3 · Dio · go_router · flutter_stripe 13
- **Responsibilities:** auth, catalog browsing, search/filter, cart, Stripe checkout,
  orders & tracking, profile/addresses, reviews & ratings, favorites, i18n, push.

## Status

Milestone **M10** is in progress, slice by slice.

- [x] Foundation + auth — HTTP client with a self-refreshing JWT interceptor,
      secure token storage, auth-gated router, sign-in / sign-up screens
- [ ] Catalog (list, search, filter, product detail)
- [ ] Cart & favorites
- [ ] Stripe checkout
- [ ] Orders & tracking
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

## Checks

```bash
flutter analyze
flutter test
```
