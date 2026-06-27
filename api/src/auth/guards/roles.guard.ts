import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Role } from '../../generated/prisma/client';
import { ROLES_KEY } from '../decorators/roles.decorator';
import { AuthUser } from '../types/jwt-payload';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<Role[] | undefined>(
      ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!requiredRoles || requiredRoles.length === 0) {
      return true;
    }
    const { user } = context
      .switchToHttp()
      .getRequest<{ user?: AuthUser }>();
    return !!user && requiredRoles.includes(user.role);
  }
}
