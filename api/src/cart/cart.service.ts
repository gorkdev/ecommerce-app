import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '../generated/prisma/client';
import { AddCartItemDto } from './dto/add-cart-item.dto';
import { UpdateCartItemDto } from './dto/update-cart-item.dto';

// Each cart line carries enough product data for the client to render the
// cart without a second round-trip (thumbnail, price, stock, currency).
const ITEM_INCLUDE = {
  product: {
    select: {
      id: true,
      slug: true,
      name: true,
      price: true,
      currency: true,
      stock: true,
      isActive: true,
      images: { orderBy: { sortOrder: 'asc' as const }, take: 1 },
    },
  },
} satisfies Prisma.CartItemInclude;

type CartWithItems = Prisma.CartGetPayload<{
  include: { items: { include: typeof ITEM_INCLUDE } };
}>;

type PurchasableProduct = {
  id: string;
  isActive: boolean;
  stock: number;
  price: Prisma.Decimal;
  currency: string;
};

@Injectable()
export class CartService {
  constructor(private readonly prisma: PrismaService) {}

  // Return the user's cart, lazily creating an empty one on first access.
  async getCart(userId: string) {
    const cart = await this.prisma.cart.upsert({
      where: { userId },
      create: { userId },
      update: {},
      include: { items: { include: ITEM_INCLUDE, orderBy: { id: 'asc' } } },
    });
    return this.toResponse(cart);
  }

  async addItem(userId: string, dto: AddCartItemDto) {
    const product = await this.ensurePurchasable(dto.productId);
    const cart = await this.ensureCart(userId);

    const existing = await this.prisma.cartItem.findUnique({
      where: { cartId_productId: { cartId: cart.id, productId: product.id } },
    });
    // Adding a product already in the cart accumulates quantity.
    const quantity = (existing?.quantity ?? 0) + dto.quantity;
    this.ensureStock(product, quantity);

    await this.prisma.cartItem.upsert({
      where: { cartId_productId: { cartId: cart.id, productId: product.id } },
      create: { cartId: cart.id, productId: product.id, quantity },
      update: { quantity },
    });

    return this.getCart(userId);
  }

  async updateItem(userId: string, productId: string, dto: UpdateCartItemDto) {
    const cart = await this.ensureCart(userId);
    await this.ensureItem(cart.id, productId);
    const product = await this.ensurePurchasable(productId);
    this.ensureStock(product, dto.quantity);

    await this.prisma.cartItem.update({
      where: { cartId_productId: { cartId: cart.id, productId } },
      data: { quantity: dto.quantity },
    });

    return this.getCart(userId);
  }

  async removeItem(userId: string, productId: string) {
    const cart = await this.ensureCart(userId);
    await this.ensureItem(cart.id, productId);

    await this.prisma.cartItem.delete({
      where: { cartId_productId: { cartId: cart.id, productId } },
    });

    return this.getCart(userId);
  }

  async clear(userId: string) {
    const cart = await this.ensureCart(userId);
    await this.prisma.cartItem.deleteMany({ where: { cartId: cart.id } });
    return this.getCart(userId);
  }

  private async ensureCart(userId: string) {
    return this.prisma.cart.upsert({
      where: { userId },
      create: { userId },
      update: {},
    });
  }

  private async ensureItem(cartId: string, productId: string) {
    const item = await this.prisma.cartItem.findUnique({
      where: { cartId_productId: { cartId, productId } },
    });
    if (!item) {
      throw new NotFoundException('Cart item not found');
    }
    return item;
  }

  // A product can only be added if it exists and is still on sale.
  private async ensurePurchasable(
    productId: string,
  ): Promise<PurchasableProduct> {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
    });
    if (!product || !product.isActive) {
      throw new NotFoundException('Product not found');
    }
    return product;
  }

  private ensureStock(product: PurchasableProduct, quantity: number) {
    if (quantity > product.stock) {
      throw new BadRequestException(
        `Only ${product.stock} unit(s) of this product are in stock`,
      );
    }
  }

  // Derive a server-side subtotal so the client never has to trust its own math.
  private toResponse(cart: CartWithItems) {
    let subtotal = new Prisma.Decimal(0);
    let itemCount = 0;
    for (const item of cart.items) {
      subtotal = subtotal.plus(item.product.price.mul(item.quantity));
      itemCount += item.quantity;
    }

    return {
      id: cart.id,
      items: cart.items,
      summary: {
        itemCount,
        subtotal: subtotal.toFixed(2),
        currency: cart.items[0]?.product.currency ?? 'TRY',
      },
    };
  }
}
