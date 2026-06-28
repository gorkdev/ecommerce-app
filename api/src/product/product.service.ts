import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '../generated/prisma/client';
import { slugify } from '../common/slugify';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { QueryProductDto } from './dto/query-product.dto';

const MAX_PAGE_SIZE = 100;

const LIST_INCLUDE = {
  category: { select: { id: true, slug: true, name: true } },
  images: { orderBy: { sortOrder: 'asc' as const } },
} satisfies Prisma.ProductInclude;

export interface PaginatedProducts {
  data: unknown[];
  meta: { page: number; limit: number; total: number; totalPages: number };
}

@Injectable()
export class ProductService {
  constructor(private readonly prisma: PrismaService) {}

  async create(dto: CreateProductDto) {
    const slug = slugify(dto.slug ?? dto.name);
    await this.ensureSlugFree(slug);
    await this.ensureCategoryExists(dto.categoryId);

    return this.prisma.product.create({
      data: {
        name: dto.name,
        slug,
        description: dto.description,
        price: dto.price,
        compareAtPrice: dto.compareAtPrice ?? null,
        currency: dto.currency ?? 'TRY',
        stock: dto.stock ?? 0,
        isActive: dto.isActive ?? true,
        categoryId: dto.categoryId,
      },
      include: LIST_INCLUDE,
    });
  }

  // Public catalog listing: active products only, with search/filter/paging.
  async findAll(query: QueryProductDto): Promise<PaginatedProducts> {
    const page = query.page ?? 1;
    const limit = Math.min(query.limit ?? 20, MAX_PAGE_SIZE);

    const where: Prisma.ProductWhereInput = { isActive: true };
    if (query.categoryId) {
      where.categoryId = query.categoryId;
    }
    if (query.search) {
      where.name = { contains: query.search, mode: 'insensitive' };
    }
    if (query.minPrice !== undefined || query.maxPrice !== undefined) {
      where.price = {};
      if (query.minPrice !== undefined) where.price.gte = query.minPrice;
      if (query.maxPrice !== undefined) where.price.lte = query.maxPrice;
    }

    const orderBy: Prisma.ProductOrderByWithRelationInput =
      query.sort === 'price_asc'
        ? { price: 'asc' }
        : query.sort === 'price_desc'
          ? { price: 'desc' }
          : { createdAt: 'desc' };

    const [data, total] = await this.prisma.$transaction([
      this.prisma.product.findMany({
        where,
        orderBy,
        skip: (page - 1) * limit,
        take: limit,
        include: LIST_INCLUDE,
      }),
      this.prisma.product.count({ where }),
    ]);

    return {
      data,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  async findBySlug(slug: string) {
    const product = await this.prisma.product.findUnique({
      where: { slug },
      include: LIST_INCLUDE,
    });
    if (!product) {
      throw new NotFoundException('Product not found');
    }
    return product;
  }

  async update(id: string, dto: UpdateProductDto) {
    await this.ensureExists(id);

    let slug: string | undefined;
    if (dto.slug !== undefined) {
      slug = slugify(dto.slug);
      await this.ensureSlugFree(slug, id);
    }
    if (dto.categoryId !== undefined) {
      await this.ensureCategoryExists(dto.categoryId);
    }

    return this.prisma.product.update({
      where: { id },
      data: {
        ...(dto.name !== undefined ? { name: dto.name } : {}),
        ...(slug !== undefined ? { slug } : {}),
        ...(dto.description !== undefined
          ? { description: dto.description }
          : {}),
        ...(dto.price !== undefined ? { price: dto.price } : {}),
        ...(dto.compareAtPrice !== undefined
          ? { compareAtPrice: dto.compareAtPrice }
          : {}),
        ...(dto.currency !== undefined ? { currency: dto.currency } : {}),
        ...(dto.stock !== undefined ? { stock: dto.stock } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
        ...(dto.categoryId !== undefined
          ? { categoryId: dto.categoryId }
          : {}),
      },
      include: LIST_INCLUDE,
    });
  }

  async remove(id: string): Promise<void> {
    await this.ensureExists(id);
    await this.prisma.product.delete({ where: { id } });
  }

  private async ensureExists(id: string) {
    const found = await this.prisma.product.findUnique({ where: { id } });
    if (!found) {
      throw new NotFoundException('Product not found');
    }
    return found;
  }

  private async ensureCategoryExists(categoryId: string) {
    const category = await this.prisma.category.findUnique({
      where: { id: categoryId },
    });
    if (!category) {
      throw new NotFoundException('Category not found');
    }
  }

  private async ensureSlugFree(slug: string, exceptId?: string) {
    const existing = await this.prisma.product.findUnique({ where: { slug } });
    if (existing && existing.id !== exceptId) {
      throw new ConflictException('Slug is already in use');
    }
  }
}
