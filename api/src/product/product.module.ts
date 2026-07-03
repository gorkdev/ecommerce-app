import { Module } from '@nestjs/common';
import { ProductController } from './product.controller';
import { AdminProductController } from './admin-product.controller';
import { ProductService } from './product.service';
import { ProductImageController } from './product-image.controller';
import { ProductImageService } from './product-image.service';

@Module({
  controllers: [
    ProductController,
    AdminProductController,
    ProductImageController,
  ],
  providers: [ProductService, ProductImageService],
  exports: [ProductService],
})
export class ProductModule {}
