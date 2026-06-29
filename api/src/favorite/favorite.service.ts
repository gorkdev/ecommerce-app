import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '../generated/prisma/client';

const PRODUCT_SELECT = {
  id: true,
  slug: true,
  name: true,
  price: true,
  currency: true,
  stock: true,
  isActive: true,
  images: { orderBy: { sortOrder: 'asc' as const }, take: 1 },
} satisfies Prisma.ProductSelect;

@Injectable()
export class FavoriteService {
  constructor(private readonly prisma: PrismaService) {}

  list(userId: string) {
    return this.prisma.favorite.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      include: { product: { select: PRODUCT_SELECT } },
    });
  }

  // Adding a favorite is idempotent: the unique (userId, productId) pair means
  // re-favouriting an already-saved product is a no-op rather than an error.
  async add(userId: string, productId: string) {
    await this.ensureProduct(productId);
    await this.prisma.favorite.upsert({
      where: { userId_productId: { userId, productId } },
      create: { userId, productId },
      update: {},
    });
    return this.list(userId);
  }

  async remove(userId: string, productId: string): Promise<void> {
    const existing = await this.prisma.favorite.findUnique({
      where: { userId_productId: { userId, productId } },
    });
    if (!existing) {
      throw new NotFoundException('Favorite not found');
    }
    await this.prisma.favorite.delete({
      where: { userId_productId: { userId, productId } },
    });
  }

  private async ensureProduct(productId: string) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
    });
    if (!product || !product.isActive) {
      throw new NotFoundException('Product not found');
    }
  }
}
