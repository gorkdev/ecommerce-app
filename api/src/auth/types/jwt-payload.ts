import { Role } from '../../generated/prisma/client';

export interface JwtPayload {
  sub: string;
  email: string;
  role: Role;
}

export interface RefreshPayload {
  sub: string;
  // Unique token id so two refresh tokens issued in the same second
  // (e.g. register immediately followed by login) never collide.
  jti: string;
}

export interface AuthUser {
  userId: string;
  email: string;
  role: Role;
}
