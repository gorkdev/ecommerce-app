import {
  BadRequestException,
  Controller,
  Headers,
  HttpCode,
  HttpStatus,
  Post,
  Req,
  RawBodyRequest,
} from '@nestjs/common';
import { Request } from 'express';
import Stripe from 'stripe';
import { PaymentService } from '../payment/payment.service';
import { OrderService } from './order.service';

// Stripe is the authoritative source for payment state: the client never
// marks an order paid. Stripe POSTs signed events here; we verify the
// signature against the raw body, then advance the order accordingly.
@Controller('payments')
export class PaymentWebhookController {
  constructor(
    private readonly payment: PaymentService,
    private readonly orders: OrderService,
  ) {}

  @Post('webhook')
  @HttpCode(HttpStatus.OK)
  async handle(
    @Req() req: RawBodyRequest<Request>,
    @Headers('stripe-signature') signature: string,
  ) {
    if (!req.rawBody) {
      throw new BadRequestException('Missing request body');
    }

    let event: Stripe.Event;
    try {
      event = this.payment.constructEvent(req.rawBody, signature);
    } catch {
      throw new BadRequestException('Invalid Stripe signature');
    }

    switch (event.type) {
      case 'payment_intent.succeeded':
        await this.orders.markPaid(
          (event.data.object as Stripe.PaymentIntent).id,
        );
        break;
      case 'payment_intent.payment_failed':
        await this.orders.markPaymentFailed(
          (event.data.object as Stripe.PaymentIntent).id,
        );
        break;
    }

    return { received: true };
  }
}
