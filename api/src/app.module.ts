import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { StorageModule } from './storage/storage.module';
import { AddressModule } from './address/address.module';
import { AuthModule } from './auth/auth.module';
import { UserModule } from './user/user.module';
import { CategoryModule } from './category/category.module';
import { ProductModule } from './product/product.module';
import { CartModule } from './cart/cart.module';
import { FavoriteModule } from './favorite/favorite.module';
import { OrderModule } from './order/order.module';
import { ReviewModule } from './review/review.module';
import { CouponModule } from './coupon/coupon.module';
import { StatsModule } from './stats/stats.module';
import { HealthController } from './health/health.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    StorageModule,
    AddressModule,
    AuthModule,
    UserModule,
    CategoryModule,
    ProductModule,
    CartModule,
    FavoriteModule,
    OrderModule,
    ReviewModule,
    CouponModule,
    StatsModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
