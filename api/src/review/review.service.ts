import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma, OrderStatus } from '../generated/prisma/client';
import { SubmitReviewDto } from './dto/submit-review.dto';
import { QueryReviewDto } from './dto/query-review.dto';

const MAX_PAGE_SIZE = 100;

// Public review payload exposes the author's display name, never their email.
const REVIEW_INCLUDE = {
  user: { select: { id: true, name: true } },
} satisfies Prisma.ReviewInclude;

// Admin listing additionally links back to the product being reviewed.
const ADMIN_REVIEW_INCLUDE = {
  user: { select: { id: true, name: true, email: true } },
  product: { select: { id: true, slug: true, name: true } },
} satisfies Prisma.ReviewInclude;

// Only orders that reached (or passed) payment count as a real purchase; a
// PENDING/CANCELLED order must not unlock the ability to review.
const PURCHASED_STATUSES: OrderStatus[] = [
  OrderStatus.PAID,
  OrderStatus.PREPARING,
  OrderStatus.SHIPPED,
  OrderStatus.DELIVERED,
];

type RatingSummary = {
  average: number;
  count: number;
  distribution: Record<1 | 2 | 3 | 4 | 5, number>;
};

@Injectable()
export class ReviewService {
  constructor(private readonly prisma: PrismaService) {}

  // ---- Public ----

  async listForProduct(productId: string) {
    await this.ensureProduct(productId);
    const [items, grouped] = await Promise.all([
      this.prisma.review.findMany({
        where: { productId },
        orderBy: { createdAt: 'desc' },
        include: REVIEW_INCLUDE,
      }),
      this.prisma.review.groupBy({
        by: ['rating'],
        where: { productId },
        _count: { _all: true },
      }),
    ]);
    return { items, summary: this.buildSummary(grouped) };
  }

  // ---- Customer (verified buyer) ----

  getOwn(userId: string, productId: string) {
    return this.prisma.review.findUnique({
      where: { productId_userId: { productId, userId } },
      include: REVIEW_INCLUDE,
    });
  }

  // Create or edit the caller's single review for a product. Gated on an actual
  // purchase; the unique (productId, userId) pair keeps it to one per customer.
  async submit(userId: string, productId: string, dto: SubmitReviewDto) {
    await this.ensureProduct(productId);
    if (!(await this.hasPurchased(userId, productId))) {
      throw new ForbiddenException(
        'You can only review products you have purchased',
      );
    }
    return this.prisma.review.upsert({
      where: { productId_userId: { productId, userId } },
      create: { productId, userId, rating: dto.rating, comment: dto.comment },
      update: { rating: dto.rating, comment: dto.comment },
      include: REVIEW_INCLUDE,
    });
  }

  async removeOwn(userId: string, productId: string): Promise<void> {
    const existing = await this.prisma.review.findUnique({
      where: { productId_userId: { productId, userId } },
    });
    if (!existing) {
      throw new NotFoundException('Review not found');
    }
    await this.prisma.review.delete({
      where: { productId_userId: { productId, userId } },
    });
  }

  // ---- Admin (moderation) ----

  async findAll(query: QueryReviewDto) {
    const page = query.page ?? 1;
    const limit = Math.min(query.limit ?? 20, MAX_PAGE_SIZE);
    const where: Prisma.ReviewWhereInput = {};
    if (query.productId) {
      where.productId = query.productId;
    }

    const [data, total] = await this.prisma.$transaction([
      this.prisma.review.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        include: ADMIN_REVIEW_INCLUDE,
      }),
      this.prisma.review.count({ where }),
    ]);

    return {
      data,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  async remove(id: string): Promise<void> {
    const existing = await this.prisma.review.findUnique({ where: { id } });
    if (!existing) {
      throw new NotFoundException('Review not found');
    }
    await this.prisma.review.delete({ where: { id } });
  }

  // ---- Helpers ----

  private async ensureProduct(productId: string) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
    });
    if (!product) {
      throw new NotFoundException('Product not found');
    }
  }

  private async hasPurchased(
    userId: string,
    productId: string,
  ): Promise<boolean> {
    const count = await this.prisma.orderItem.count({
      where: {
        productId,
        order: { userId, status: { in: PURCHASED_STATUSES } },
      },
    });
    return count > 0;
  }

  private buildSummary(
    grouped: { rating: number; _count: { _all: number } }[],
  ): RatingSummary {
    const distribution: Record<1 | 2 | 3 | 4 | 5, number> = {
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
    };
    let count = 0;
    let weighted = 0;
    for (const g of grouped) {
      const c = g._count._all;
      distribution[g.rating as 1 | 2 | 3 | 4 | 5] = c;
      count += c;
      weighted += g.rating * c;
    }
    const average = count ? Math.round((weighted / count) * 10) / 10 : 0;
    return { average, count, distribution };
  }
}
