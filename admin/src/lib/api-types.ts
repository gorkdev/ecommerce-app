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

export interface Category extends CategoryRef {
  parentId: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface CategoryInput {
  name: string;
  slug?: string;
  parentId?: string | null;
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

export type OrderStatus =
  | "PENDING"
  | "PAID"
  | "PREPARING"
  | "SHIPPED"
  | "DELIVERED"
  | "CANCELLED"
  | "REFUNDED";

export interface OrderItem {
  id: string;
  productId: string;
  nameSnapshot: string;
  priceSnapshot: string;
  quantity: number;
  product?: {
    id: string;
    slug: string;
    images: ProductImage[];
  } | null;
}

export interface OrderAddress {
  id: string;
  fullName: string;
  phone: string;
  line1: string;
  line2: string | null;
  city: string;
  district: string;
  postalCode: string;
  country: string;
}

export type CouponType = "PERCENTAGE" | "FIXED";

export interface OrderCouponRef {
  id: string;
  code: string;
  type: CouponType;
}

export interface OrderCustomer {
  id: string;
  email: string;
  name: string;
}

export interface Order {
  id: string;
  userId: string;
  status: OrderStatus;
  subtotal: string;
  discountTotal: string;
  total: string;
  currency: string;
  addressId: string | null;
  couponId: string | null;
  stripePaymentIntentId: string | null;
  createdAt: string;
  updatedAt: string;
  items: OrderItem[];
  address: OrderAddress | null;
  coupon: OrderCouponRef | null;
  user?: OrderCustomer;
}

export interface Coupon {
  id: string;
  code: string;
  type: CouponType;
  value: string;
  minSubtotal: string;
  maxUses: number | null;
  usedCount: number;
  expiresAt: string | null;
  isActive: boolean;
  createdAt: string;
}

export interface CouponInput {
  code: string;
  type: CouponType;
  value: number;
  minSubtotal?: number;
  maxUses?: number | null;
  expiresAt?: string | null;
  isActive?: boolean;
}

export interface ReviewProductRef {
  id: string;
  slug: string;
  name: string;
}

// Admin review rows carry the author's email (customer-facing payloads never do)
// so moderators can identify who wrote a flagged review.
export interface ReviewAuthor {
  id: string;
  name: string;
  email: string;
}

export interface AdminReview {
  id: string;
  productId: string;
  userId: string;
  rating: number;
  comment: string | null;
  createdAt: string;
  product: ReviewProductRef;
  user: ReviewAuthor;
}

export interface AdminUserListItem {
  id: string;
  email: string;
  name: string;
  role: Role;
  createdAt: string;
  updatedAt: string;
  _count: { orders: number; reviews: number };
}

export interface AdminUserOrderRef {
  id: string;
  status: OrderStatus;
  total: string;
  currency: string;
  createdAt: string;
}

export interface AdminUserDetail extends AdminUserListItem {
  orders: AdminUserOrderRef[];
}
