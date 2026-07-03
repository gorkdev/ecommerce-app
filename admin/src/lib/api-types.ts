// Shapes mirrored from the NestJS API responses. Money fields arrive as strings
// because Prisma serializes Decimal columns to strings.

export type Role = "ADMIN" | "CUSTOMER";

export interface PublicUser {
  id: string;
  email: string;
  name: string;
  role: Role;
}

export interface AuthResult {
  user: PublicUser;
  accessToken: string;
  refreshToken: string;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface CategoryRef {
  id: string;
  slug: string;
  name: string;
}

export interface CategoryNode extends CategoryRef {
  parentId: string | null;
  children: CategoryNode[];
}

export interface ProductImage {
  id: string;
  productId: string;
  url: string;
  sortOrder: number;
}

export interface Product {
  id: string;
  slug: string;
  name: string;
  description: string;
  price: string;
  compareAtPrice: string | null;
  currency: string;
  stock: number;
  isActive: boolean;
  categoryId: string;
  createdAt: string;
  updatedAt: string;
  category: CategoryRef;
  images: ProductImage[];
}

export interface PageMeta {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
}

export interface Paginated<T> {
  data: T[];
  meta: PageMeta;
}

export interface ProductInput {
  name: string;
  slug?: string;
  description: string;
  price: number;
  compareAtPrice?: number;
  currency?: string;
  stock?: number;
  isActive?: boolean;
  categoryId: string;
}
