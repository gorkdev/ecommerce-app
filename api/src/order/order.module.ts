import { Module } from '@nestjs/common';
import { PaymentModule } from '../payment/payment.module';
import { CouponModule } from '../coupon/coupon.module';
import { OrderController } from './order.controller';
import { AdminOrderController } from './admin-order.controller';
import { PaymentWebhookController } from './payment-webhook.controller';
import { OrderService } from './order.service';

@Module({
  imports: [PaymentModule, CouponModule],
  controllers: [
    OrderController,
    AdminOrderController,
    PaymentWebhookController,
  ],
  providers: [OrderService],
  exports: [OrderService],
})
export class OrderModule {}
