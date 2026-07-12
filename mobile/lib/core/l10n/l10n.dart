import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';
import '../network/api_exception.dart';

export '../../l10n/generated/app_localizations.dart';

extension L10nContext on BuildContext {
  /// The app's localized strings — shorthand for `AppLocalizations.of(this)`.
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension L10nErrors on AppLocalizations {
  /// The message to show a user for [error].
  ///
  /// Server-authored messages ([ApiStatusException]) surface verbatim — they
  /// are the authority on what went wrong. Client-authored ones (network
  /// failures, unclassifiable errors) are localized here instead.
  String errorText(Object? error) => switch (error) {
    final ApiStatusException error => error.message,
    NetworkException() => networkError,
    _ => somethingWentWrong,
  };
}
