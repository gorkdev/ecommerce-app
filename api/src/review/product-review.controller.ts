import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AuthUser } from '../auth/types/jwt-payload';
import { ReviewService } from './review.service';
import { SubmitReviewDto } from './dto/submit-review.dto';

@Controller('products/:productId/reviews')
export class ProductReviewController {
  constructor(private readonly reviewService: ReviewService) {}

  // Public: anyone can read a product's reviews and its rating summary.
  @Get()
  list(@Param('productId') productId: string) {
    return this.reviewService.listForProduct(productId);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  myReview(
    @CurrentUser() user: AuthUser,
    @Param('productId') productId: string,
  ) {
    return this.reviewService.getOwn(user.userId, productId);
  }

  @UseGuards(JwtAuthGuard)
  @Post()
  submit(
    @CurrentUser() user: AuthUser,
    @Param('productId') productId: string,
    @Body() dto: SubmitReviewDto,
  ) {
    return this.reviewService.submit(user.userId, productId, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('me')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@CurrentUser() user: AuthUser, @Param('productId') productId: string) {
    return this.reviewService.removeOwn(user.userId, productId);
  }
}
