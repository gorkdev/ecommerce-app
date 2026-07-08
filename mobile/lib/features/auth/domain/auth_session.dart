import 'auth_user.dart';

/// What `POST /auth/login` and `POST /auth/register` hand back: the user plus a
/// fresh JWT pair.
final class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
  );

  final AuthUser user;
  final String accessToken;
  final String refreshToken;
}
