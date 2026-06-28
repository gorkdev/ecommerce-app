import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { ALLOWED_IMAGE_TYPES, PresignUploadDto } from './dto/presign-upload.dto';
import { AttachImageDto } from './dto/attach-image.dto';

@Injectable()
export class ProductImageService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  // Step 1: hand the client a short-lived presigned PUT URL to upload directly.
  async createUploadUrl(productId: string, dto: PresignUploadDto) {
    await this.ensureProduct(productId);
    const ext = ALLOWED_IMAGE_TYPES[dto.contentType];
    const key = this.storage.buildKey(productId, ext);
    const uploadUrl = await this.storage.createPresignedUpload(
      key,
      dto.contentType,
    );
    return { key, uploadUrl, publicUrl: this.storage.publicUrl(key) };
  }

  // Step 2: once uploaded, register the image against the product.
  async attach(productId: string, dto: AttachImageDto) {
    await this.ensureProduct(productId);

    // Guard: the key must belong to this product's namespace.
    if (!dto.key.startsWith(`products/${productId}/`)) {
      throw new BadRequestException('Key does not belong to this product');
    }

    return this.prisma.productImage.create({
      data: {
        productId,
        url: this.storage.publicUrl(dto.key),
        sortOrder: dto.sortOrder ?? 0,
      },
    });
  }

  async remove(productId: string, imageId: string): Promise<void> {
    const image = await this.prisma.productImage.findUnique({
      where: { id: imageId },
    });
    if (!image || image.productId !== productId) {
      throw new NotFoundException('Image not found');
    }

    await this.storage.deleteObject(this.storage.keyFromUrl(image.url));
    await this.prisma.productImage.delete({ where: { id: imageId } });
  }

  private async ensureProduct(productId: string) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
    });
    if (!product) {
      throw new NotFoundException('Product not found');
    }
    return product;
  }
}
