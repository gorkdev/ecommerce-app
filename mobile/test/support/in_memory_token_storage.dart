import 'package:ecommerce_app/core/storage/token_storage.dart';

/// A [TokenStorage] with no platform channel behind it, plus counters so tests
/// can assert *how many times* the storage was touched.
final class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage({this.accessToken, this.refreshToken});

  String? accessToken;
  String? refreshToken;

  int saveCount = 0;
  int clearCount = 0;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    saveCount++;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    clearCount++;
  }
}
