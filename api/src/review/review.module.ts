import { Module } from '@nestjs/common';
import { ProductReviewController } from './product-review.controller';
import { AdminReviewController } from './admin-review.controller';
import { ReviewService } from './review.service';

@Module({
  controllers: [ProductReviewController, AdminReviewController],
  providers: [ReviewService],
  exports: [ReviewService],
})
export class ReviewModule {}
