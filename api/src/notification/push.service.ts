import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { App, cert, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';

export interface PushMessage {
  title: string;
  body: string;
  // Extra payload the app deep-links from (FCM requires string values).
  data: Record<string, string>;
}

export interface PushSendResult {
  successCount: number;
  // Tokens Firebase reported as permanently dead (app uninstalled, token
  // rotated) — the caller should delete them so we stop pushing into the void.
  invalidTokens: string[];
}

// Codes that mean the token itself is unusable. Anything else (throttling,
// transient server errors) keeps the token for the next attempt.
const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

// The single seam that touches the Firebase Admin SDK — the push mirror of
// PaymentService for Stripe. Unlike Stripe, push is optional infrastructure:
// without FIREBASE_SERVICE_ACCOUNT the API runs fine and pushes are skipped.
@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);
  private readonly app: App | null = null;

  constructor(config: ConfigService) {
    const serviceAccountPath = config.get<string>('FIREBASE_SERVICE_ACCOUNT');
    if (!serviceAccountPath) {
      this.logger.log(
        'FIREBASE_SERVICE_ACCOUNT is not set — push notifications disabled',
      );
      return;
    }
    // cert() reads the key file eagerly, so a wrong path fails at boot
    // instead of silently dropping every notification later.
    this.app = initializeApp({ credential: cert(serviceAccountPath) });
  }

  get enabled(): boolean {
    return this.app !== null;
  }

  // Fan a single message out to a user's devices. FCM caps a multicast at
  // 500 tokens, far beyond any realistic per-user device count.
  async sendToTokens(
    tokens: string[],
    message: PushMessage,
  ): Promise<PushSendResult> {
    if (!this.app || tokens.length === 0) {
      return { successCount: 0, invalidTokens: [] };
    }
    const response = await getMessaging(this.app).sendEachForMulticast({
      tokens,
      notification: { title: message.title, body: message.body },
      data: message.data,
    });
    const invalidTokens: string[] = [];
    response.responses.forEach((result, index) => {
      if (result.success || !result.error) {
        return;
      }
      if (INVALID_TOKEN_CODES.has(result.error.code)) {
        invalidTokens.push(tokens[index]);
      } else {
        this.logger.warn(`Push delivery failed: ${result.error.message}`);
      }
    });
    return { successCount: response.successCount, invalidTokens };
  }
}
