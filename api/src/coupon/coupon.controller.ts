import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AuthUser } from '../auth/types/jwt-payload';
import { CouponService } from './coupon.service';
import { ApplyCouponDto } from './dto/apply-coupon.dto';

@UseGuards(JwtAuthGuard)
@Controller('coupons')
export class CouponController {
  constructor(private readonly couponService: CouponService) {}

  // Quote the discount a code would give against the caller's current cart.
  @Post('apply')
  apply(@CurrentUser() user: AuthUser, @Body() dto: ApplyCouponDto) {
    return this.couponService.previewForUser(user.userId, dto.code);
  }
}
