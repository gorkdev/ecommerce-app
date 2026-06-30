import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Stripe from 'stripe';

export interface CreatePaymentIntentParams {
  // Amount in the currency's minor unit (e.g. kuruş for TRY, cents for USD).
  amountMinor: number;
  currency: string;
  orderId: string;
}

// The single seam that touches the Stripe SDK. Everything else in the app
// talks to this service, which keeps the rest of the code (and its tests)
// free of any Stripe coupling — in tests this provider is overridden.
@Injectable()
export class PaymentService {
  private readonly stripe: Stripe;
  private readonly webhookSecret: string;

  constructor(config: ConfigService) {
    this.stripe = new Stripe(config.getOrThrow<string>('STRIPE_SECRET_KEY'));
    this.webhookSecret = config.getOrThrow<string>('STRIPE_WEBHOOK_SECRET');
  }

  createPaymentIntent(
    params: CreatePaymentIntentParams,
  ): Promise<Stripe.PaymentIntent> {
    return this.stripe.paymentIntents.create({
      amount: params.amountMinor,
      currency: params.currency.toLowerCase(),
      // The order id lets the webhook tie an intent back to its order.
      metadata: { orderId: params.orderId },
      automatic_payment_methods: { enabled: true },
    });
  }

  // Verify the Stripe signature against the raw request body. Throws if the
  // payload was tampered with or the signature does not match our secret.
  constructEvent(payload: Buffer, signature: string): Stripe.Event {
    return this.stripe.webhooks.constructEvent(
      payload,
      signature,
      this.webhookSecret,
    );
  }
}
