import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { PushService } from './push.service';

// The Firebase Admin SDK is fully mocked: these tests exercise the seam's
// own logic (config gating, invalid-token triage), never Google's servers.
jest.mock('firebase-admin/app', () => ({
  initializeApp: jest.fn(() => ({ name: 'test-app' })),
  cert: jest.fn((path: string) => ({ path })),
}));
jest.mock('firebase-admin/messaging', () => ({
  getMessaging: jest.fn(),
}));

const message = {
  title: 'Order shipped',
  body: 'Your order is on its way.',
  data: { type: 'order-status', orderId: 'o1', status: 'SHIPPED' },
};

async function buildService(serviceAccount: string | undefined) {
  const moduleRef = await Test.createTestingModule({
    providers: [
      PushService,
      {
        provide: ConfigService,
        useValue: { get: jest.fn().mockReturnValue(serviceAccount) },
      },
    ],
  }).compile();
  return moduleRef.get(PushService);
}

describe('PushService', () => {
  let sendEachForMulticast: jest.Mock;

  beforeEach(() => {
    jest.clearAllMocks();
    sendEachForMulticast = jest.fn();
    (getMessaging as jest.Mock).mockReturnValue({ sendEachForMulticast });
  });

  it('stays disabled without FIREBASE_SERVICE_ACCOUNT', async () => {
    const service = await buildService(undefined);

    expect(service.enabled).toBe(false);
    expect(initializeApp).not.toHaveBeenCalled();

    const result = await service.sendToTokens(['tok-1'], message);
    expect(result).toEqual({ successCount: 0, invalidTokens: [] });
    expect(sendEachForMulticast).not.toHaveBeenCalled();
  });

  it('initializes Firebase from the configured service account', async () => {
    const service = await buildService('./firebase-service-account.json');

    expect(service.enabled).toBe(true);
    expect(initializeApp).toHaveBeenCalledWith({
      credential: { path: './firebase-service-account.json' },
    });
  });

  it('multicasts the notification and data payload to every token', async () => {
    const service = await buildService('./sa.json');
    sendEachForMulticast.mockResolvedValue({
      successCount: 2,
      responses: [{ success: true }, { success: true }],
    });

    const result = await service.sendToTokens(['tok-1', 'tok-2'], message);

    expect(sendEachForMulticast).toHaveBeenCalledWith({
      tokens: ['tok-1', 'tok-2'],
      notification: { title: message.title, body: message.body },
      data: message.data,
    });
    expect(result).toEqual({ successCount: 2, invalidTokens: [] });
  });

  it('skips the network round-trip for an empty token list', async () => {
    const service = await buildService('./sa.json');

    const result = await service.sendToTokens([], message);

    expect(result).toEqual({ successCount: 0, invalidTokens: [] });
    expect(sendEachForMulticast).not.toHaveBeenCalled();
  });

  it('flags dead tokens but keeps transiently failing ones', async () => {
    const service = await buildService('./sa.json');
    sendEachForMulticast.mockResolvedValue({
      successCount: 1,
      responses: [
        { success: true },
        {
          success: false,
          error: {
            code: 'messaging/registration-token-not-registered',
            message: 'gone',
          },
        },
        {
          success: false,
          error: { code: 'messaging/internal-error', message: 'try later' },
        },
      ],
    });

    const result = await service.sendToTokens(
      ['tok-live', 'tok-dead', 'tok-flaky'],
      message,
    );

    expect(result).toEqual({ successCount: 1, invalidTokens: ['tok-dead'] });
  });
});
