import {
  Body,
  Controller,
  Delete,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Role } from '../generated/prisma/client';
import { ProductImageService } from './product-image.service';
import { PresignUploadDto } from './dto/presign-upload.dto';
import { AttachImageDto } from './dto/attach-image.dto';

// All image management is admin-only.
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
@Controller('products/:productId/images')
export class ProductImageController {
  constructor(private readonly productImageService: ProductImageService) {}

  @Post('presign')
  presign(
    @Param('productId') productId: string,
    @Body() dto: PresignUploadDto,
  ) {
    return this.productImageService.createUploadUrl(productId, dto);
  }

  @Post()
  attach(@Param('productId') productId: string, @Body() dto: AttachImageDto) {
    return this.productImageService.attach(productId, dto);
  }

  @HttpCode(HttpStatus.NO_CONTENT)
  @Delete(':imageId')
  remove(
    @Param('productId') productId: string,
    @Param('imageId') imageId: string,
  ) {
    return this.productImageService.remove(productId, imageId);
  }
}
