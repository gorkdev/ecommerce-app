import 'package:ecommerce_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The [MaterialApp] for widget tests: the app's localizations are wired and
/// the locale pinned, so string assertions hold on any machine. Pass another
/// [locale] to render a different language (the Turkish smoke tests do).
Widget testApp({
  Widget? home,
  GoRouter? router,
  Locale locale = const Locale('en'),
}) {
  if (router != null) {
    return MaterialApp.router(
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
  return MaterialApp(
    home: home,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}
