const createIntentMock = jest.fn();
const constructEventMock = jest.fn();

// Replace the Stripe SDK with a stub so no network call (or real key) is needed.
jest.mock('stripe', () =>
  jest.fn().mockImplementation(() => ({
    paymentIntents: { create: createIntentMock },
    webhooks: { constructEvent: constructEventMock },
  })),
);

import { ConfigService } from '@nestjs/config';
import { PaymentService } from './payment.service';

describe('PaymentService', () => {
  let service: PaymentService;

  beforeEach(() => {
    createIntentMock.mockReset();
    constructEventMock.mockReset();
    const config = {
      getOrThrow: (key: string) =>
        key === 'STRIPE_SECRET_KEY' ? 'sk_test_x' : 'whsec_x',
    } as unknown as ConfigService;
    service = new PaymentService(config);
  });

  it('maps params onto a Stripe PaymentIntent', async () => {
    createIntentMock.mockResolvedValue({ id: 'pi_1' });

    await service.createPaymentIntent({
      amountMinor: 5000,
      currency: 'TRY',
      orderId: 'o1',
    });

    expect(createIntentMock).toHaveBeenCalledWith(
      expect.objectContaining({
        amount: 5000,
        currency: 'try',
        metadata: { orderId: 'o1' },
      }),
    );
  });

  it('delegates signature verification to the SDK with the webhook secret', () => {
    const payload = Buffer.from('{}');
    service.constructEvent(payload, 'sig');

    expect(constructEventMock).toHaveBeenCalledWith(payload, 'sig', 'whsec_x');
  });
});
