import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { OrderStatus } from '../generated/prisma/client';
import { PushService } from './push.service';
import { orderStatusMessage } from './push-messages';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';

@Injectable()
export class NotificationService {
  private readonly logger = new Logger(NotificationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly push: PushService,
  ) {}

  // A token identifies a device, not a user: when another account signs in
  // on the same phone the token must move with it, hence upsert keyed by
  // token. Re-registering also refreshes the platform and language.
  registerToken(userId: string, dto: RegisterDeviceTokenDto) {
    const data = {
      userId,
      platform: dto.platform,
      locale: dto.locale ?? 'en',
    };
    return this.prisma.deviceToken.upsert({
      where: { token: dto.token },
      update: data,
      create: { ...data, token: dto.token },
    });
  }

  // Sign-out cleanup. deleteMany keeps it idempotent and scoped: removing a
  // token that is already gone — or that belongs to someone else — is a no-op.
  async removeToken(userId: string, token: string): Promise<void> {
    await this.prisma.deviceToken.deleteMany({ where: { token, userId } });
  }

  // Called fire-and-forget from order flows: a broken push must never fail
  // the request that triggered it, so every failure ends here as a log line.
  async notifyOrderStatus(
    userId: string,
    orderId: string,
    status: OrderStatus,
  ): Promise<void> {
    try {
      if (!this.push.enabled) {
        return;
      }
      const devices = await this.prisma.deviceToken.findMany({
        where: { userId },
      });
      if (devices.length === 0) {
        return;
      }

      // Devices registered in different languages each get their own copy.
      const tokensByLocale = new Map<string, string[]>();
      for (const device of devices) {
        const tokens = tokensByLocale.get(device.locale) ?? [];
        tokens.push(device.token);
        tokensByLocale.set(device.locale, tokens);
      }

      const invalid: string[] = [];
      for (const [locale, tokens] of tokensByLocale) {
        const message = orderStatusMessage(locale, status);
        if (!message) {
          continue;
        }
        const result = await this.push.sendToTokens(tokens, {
          ...message,
          // The app deep-links to the order detail screen from this payload.
          data: { type: 'order-status', orderId, status },
        });
        invalid.push(...result.invalidTokens);
      }
      if (invalid.length > 0) {
        await this.prisma.deviceToken.deleteMany({
          where: { token: { in: invalid } },
        });
      }
    } catch (error) {
      this.logger.error(
        `Failed to push status ${status} for order ${orderId}`,
        error instanceof Error ? error.stack : String(error),
      );
    }
  }
}
