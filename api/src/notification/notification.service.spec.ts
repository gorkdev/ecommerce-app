import { Test } from '@nestjs/testing';
import { NotificationService } from './notification.service';
import { PushService } from './push.service';
import { PrismaService } from '../prisma/prisma.service';
import { OrderStatus } from '../generated/prisma/client';

type PrismaMock = {
  deviceToken: {
    upsert: jest.Mock;
    deleteMany: jest.Mock;
    findMany: jest.Mock;
  };
};

const device = (over: Partial<Record<string, unknown>> = {}) => ({
  id: 'dt1',
  userId: 'u1',
  token: 'tok-1',
  platform: 'android',
  locale: 'en',
  ...over,
});

describe('NotificationService', () => {
  let service: NotificationService;
  let prisma: PrismaMock;
  let push: { enabled: boolean; sendToTokens: jest.Mock };

  beforeEach(async () => {
    prisma = {
      deviceToken: {
        upsert: jest.fn(),
        deleteMany: jest.fn(),
        findMany: jest.fn(),
      },
    };
    push = {
      enabled: true,
      sendToTokens: jest
        .fn()
        .mockResolvedValue({ successCount: 1, invalidTokens: [] }),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        NotificationService,
        { provide: PrismaService, useValue: prisma },
        { provide: PushService, useValue: push },
      ],
    }).compile();

    service = moduleRef.get(NotificationService);
  });

  describe('registerToken', () => {
    it('upserts keyed by token so a device follows its current user', () => {
      service.registerToken('u2', {
        token: 'tok-1',
        platform: 'ios',
        locale: 'tr',
      });

      expect(prisma.deviceToken.upsert).toHaveBeenCalledWith({
        where: { token: 'tok-1' },
        update: { userId: 'u2', platform: 'ios', locale: 'tr' },
        create: { userId: 'u2', platform: 'ios', locale: 'tr', token: 'tok-1' },
      });
    });

    it('defaults the locale to English', () => {
      service.registerToken('u1', { token: 'tok-1', platform: 'android' });

      expect(prisma.deviceToken.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          update: expect.objectContaining({ locale: 'en' }),
        }),
      );
    });
  });

  describe('removeToken', () => {
    it('deletes only the caller\'s copy of the token', async () => {
      await service.removeToken('u1', 'tok-1');

      expect(prisma.deviceToken.deleteMany).toHaveBeenCalledWith({
        where: { token: 'tok-1', userId: 'u1' },
      });
    });
  });

  describe('notifyOrderStatus', () => {
    it('does nothing when push is not configured', async () => {
      push.enabled = false;

      await service.notifyOrderStatus('u1', 'o1', OrderStatus.SHIPPED);

      expect(prisma.deviceToken.findMany).not.toHaveBeenCalled();
      expect(push.sendToTokens).not.toHaveBeenCalled();
    });

    it('does nothing for a user with no registered devices', async () => {
      prisma.deviceToken.findMany.mockResolvedValue([]);

      await service.notifyOrderStatus('u1', 'o1', OrderStatus.SHIPPED);

      expect(push.sendToTokens).not.toHaveBeenCalled();
    });

    it('sends each locale group its own translated copy', async () => {
      prisma.deviceToken.findMany.mockResolvedValue([
        device({ token: 'tok-en-1' }),
        device({ token: 'tok-tr', locale: 'tr' }),
        device({ token: 'tok-en-2' }),
      ]);

      await service.notifyOrderStatus('u1', 'o1', OrderStatus.SHIPPED);

      expect(push.sendToTokens).toHaveBeenCalledTimes(2);
      expect(push.sendToTokens).toHaveBeenCalledWith(['tok-en-1', 'tok-en-2'], {
        title: 'Order shipped',
        body: 'Your order is on its way.',
        data: { type: 'order-status', orderId: 'o1', status: 'SHIPPED' },
      });
      expect(push.sendToTokens).toHaveBeenCalledWith(['tok-tr'], {
        title: 'Sipariş kargoda',
        body: 'Siparişiniz yola çıktı.',
        data: { type: 'order-status', orderId: 'o1', status: 'SHIPPED' },
      });
    });

    it('falls back to English for a locale without a catalog', async () => {
      prisma.deviceToken.findMany.mockResolvedValue([
        device({ locale: 'de' }),
      ]);

      await service.notifyOrderStatus('u1', 'o1', OrderStatus.DELIVERED);

      expect(push.sendToTokens).toHaveBeenCalledWith(
        ['tok-1'],
        expect.objectContaining({ title: 'Order delivered' }),
      );
    });

    it('prunes tokens Firebase reports as dead', async () => {
      prisma.deviceToken.findMany.mockResolvedValue([
        device({ token: 'tok-live' }),
        device({ token: 'tok-dead' }),
      ]);
      push.sendToTokens.mockResolvedValue({
        successCount: 1,
        invalidTokens: ['tok-dead'],
      });

      await service.notifyOrderStatus('u1', 'o1', OrderStatus.SHIPPED);

      expect(prisma.deviceToken.deleteMany).toHaveBeenCalledWith({
        where: { token: { in: ['tok-dead'] } },
      });
    });

    it('never sends for PENDING — the status an order is born in', async () => {
      prisma.deviceToken.findMany.mockResolvedValue([device()]);

      await service.notifyOrderStatus('u1', 'o1', OrderStatus.PENDING);

      expect(push.sendToTokens).not.toHaveBeenCalled();
    });

    it('swallows push failures instead of failing the caller', async () => {
      prisma.deviceToken.findMany.mockResolvedValue([device()]);
      push.sendToTokens.mockRejectedValue(new Error('FCM is down'));

      await expect(
        service.notifyOrderStatus('u1', 'o1', OrderStatus.SHIPPED),
      ).resolves.toBeUndefined();
    });
  });
});
