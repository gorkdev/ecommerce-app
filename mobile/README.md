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
- [x] Profile & addresses — account hub, address book with a single
      server-kept default, delivery address picker at checkout
- [x] Reviews & ratings — rating summary with distribution bars, one
      write/edit/delete review per verified buyer

All M10 slices are done — the customer flow is complete end to end.

Milestone **M11** — internationalization — is also done:

- [x] i18n — every user-facing string localized (English + Turkish),
      locale-aware dates, an in-app language picker on the profile screen
      with the choice persisted across launches

Milestone **M12** — push notifications — is also done:

- [x] Push (FCM) — the device registers for order-status notifications
      while signed in; a notification tap deep-links to the order, a
      foreground message becomes a snackbar with a View action

The app was then fully redesigned in a "soft modern" language:

- [x] Design system — `AppTokens` ThemeExtension (pastel palette with
      WCAG-AA ink foregrounds, spacing/radius scales, one soft shadow
      recipe), bundled Plus Jakarta Sans, pill buttons and chips
- [x] Bottom navigation shell — five tabs with a live cart badge;
      full-screen flows cover the bar on the root navigator
- [x] Every screen rebuilt on the tokens: greeting-led catalog with a
      promo banner, edge-to-edge product gallery with a sticky buy bar,
      receipt-style summaries, pastel order-status chips and timeline

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

## Localization

Strings live in ARB tables under `lib/l10n/` (`app_en.arb` is the template,
`app_tr.arb` the Turkish translation). Flutter's built-in `gen_l10n` compiles
them into `lib/l10n/generated/` on every `flutter pub get` and build — no
build_runner involved. To add a language: create `app_<code>.arb`, translate
every key, and list the locale in `ios/Runner/Info.plist`.

The app follows the device language by default; the profile screen has a
language picker whose choice is persisted (`shared_preferences`) and applied
app-wide immediately. Dates format through locale-aware skeletons, so field
order adapts per language. One deliberate boundary: messages authored by the
API (validation errors, business rules) surface verbatim — the server is the
authority on what went wrong.

## Push notifications

Order-status changes arrive as FCM notifications. While someone is signed
in, the app registers its device token (and the app language, so the server
renders the copy in it) with the API; sign-out removes it. A notification
tap — from the tray or a cold start — deep-links straight to the order, and
a message arriving in the foreground shows a snackbar with a View action.

Firebase config is per-developer and gitignored, so a clean checkout builds
and runs with push silently disabled. To enable it:

1. Create a Firebase project and an Android/iOS app in it
   (`flutterfire configure` does both and drops the files in place).
2. `google-services.json` goes to `android/app/`,
   `GoogleService-Info.plist` to `ios/Runner/` (iOS additionally needs an
   APNs key uploaded to Firebase and the Push Notifications capability).
3. Point the API at the same project (see `../api/README.md`).

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

## Regenerating the README screenshots

`integration_test/screenshots_test.dart` walks the real app — sign-in,
catalog, product detail, cart, orders, order tracking, profile — against a
locally running, seeded API and drops the screenshots into
`../docs/screenshots/`. With an Android emulator running and the API up
(seed applied — see `../api`):

```bash
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart
```
