import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { slugify } from '../common/slugify';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';

export interface CategoryNode {
  id: string;
  slug: string;
  name: string;
  parentId: string | null;
  children: CategoryNode[];
}

@Injectable()
export class CategoryService {
  constructor(private readonly prisma: PrismaService) {}

  async create(dto: CreateCategoryDto) {
    const slug = slugify(dto.slug ?? dto.name);
    await this.ensureSlugFree(slug);
    if (dto.parentId) {
      await this.ensureExists(dto.parentId);
    }
    return this.prisma.category.create({
      data: { name: dto.name, slug, parentId: dto.parentId ?? null },
    });
  }

  // Public listing: the full category forest with children nested under parents.
  async findTree(): Promise<CategoryNode[]> {
    const all = await this.prisma.category.findMany({
      orderBy: { name: 'asc' },
    });

    const byId = new Map<string, CategoryNode>();
    for (const c of all) {
      byId.set(c.id, {
        id: c.id,
        slug: c.slug,
        name: c.name,
        parentId: c.parentId,
        children: [],
      });
    }

    const roots: CategoryNode[] = [];
    for (const node of byId.values()) {
      const parent = node.parentId ? byId.get(node.parentId) : undefined;
      if (parent) {
        parent.children.push(node);
      } else {
        roots.push(node);
      }
    }
    return roots;
  }

  async findBySlug(slug: string) {
    const category = await this.prisma.category.findUnique({
      where: { slug },
      include: { children: true },
    });
    if (!category) {
      throw new NotFoundException('Category not found');
    }
    return category;
  }

  async update(id: string, dto: UpdateCategoryDto) {
    await this.ensureExists(id);

    let slug: string | undefined;
    if (dto.slug !== undefined) {
      slug = slugify(dto.slug);
      await this.ensureSlugFree(slug, id);
    }

    // A non-null parentId re-parents the category; guard against cycles.
    // (parentId === null detaches it to the top level and needs no checks.)
    if (dto.parentId) {
      if (dto.parentId === id) {
        throw new ConflictException('A category cannot be its own parent');
      }
      await this.ensureExists(dto.parentId);
      const descendants = await this.collectDescendantIds(id);
      if (descendants.has(dto.parentId)) {
        throw new ConflictException(
          'A category cannot be moved under its own descendant',
        );
      }
    }

    return this.prisma.category.update({
      where: { id },
      data: {
        ...(dto.name !== undefined ? { name: dto.name } : {}),
        ...(slug !== undefined ? { slug } : {}),
        ...(dto.parentId !== undefined ? { parentId: dto.parentId } : {}),
      },
    });
  }

  async remove(id: string): Promise<void> {
    await this.ensureExists(id);
    const productCount = await this.prisma.product.count({
      where: { categoryId: id },
    });
    if (productCount > 0) {
      throw new ConflictException(
        'Cannot delete a category that still has products',
      );
    }
    await this.prisma.category.delete({ where: { id } });
  }

  // Every category id in the subtree below `rootId` (exclusive of the root).
  private async collectDescendantIds(rootId: string): Promise<Set<string>> {
    const all = await this.prisma.category.findMany({
      select: { id: true, parentId: true },
    });

    const childrenByParent = new Map<string, string[]>();
    for (const c of all) {
      if (c.parentId) {
        const list = childrenByParent.get(c.parentId) ?? [];
        list.push(c.id);
        childrenByParent.set(c.parentId, list);
      }
    }

    const descendants = new Set<string>();
    const stack = [rootId];
    while (stack.length > 0) {
      const current = stack.pop() as string;
      for (const child of childrenByParent.get(current) ?? []) {
        if (!descendants.has(child)) {
          descendants.add(child);
          stack.push(child);
        }
      }
    }
    return descendants;
  }

  private async ensureExists(id: string) {
    const found = await this.prisma.category.findUnique({ where: { id } });
    if (!found) {
      throw new NotFoundException('Category not found');
    }
    return found;
  }

  private async ensureSlugFree(slug: string, exceptId?: string) {
    const existing = await this.prisma.category.findUnique({ where: { slug } });
    if (existing && existing.id !== exceptId) {
      throw new ConflictException('Slug is already in use');
    }
  }
}
