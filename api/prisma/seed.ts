import 'dotenv/config';
import { hash as argonHash } from '@node-rs/argon2';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { PrismaPg } from '@prisma/adapter-pg';
import { OrderStatus, PrismaClient } from '../src/generated/prisma/client';
import { productImagePng } from './seed-assets';

// Demo dataset for local development, screenshots and reviewer walk-throughs.
// Idempotent: every record is upserted against a stable natural key (email,
// slug, coupon code, payment-intent id, …), so `prisma db seed` can run any
// number of times without duplicating data. Passwords are re-hashed on every
// run, which deliberately restores the documented demo credentials.

const ADMIN_PASSWORD = 'Admin123!';
const CUSTOMER_PASSWORD = 'Customer123!';
const IMAGES_PER_PRODUCT = 2;

type CategorySeed = { slug: string; name: string; children: { slug: string; name: string }[] };
type ProductSeed = {
  slug: string;
  name: string;
  description: string;
  price: string;
  compareAtPrice?: string;
  stock: number;
  category: string;
};
type CustomerSeed = { email: string; name: string; city: string; district: string };
type OrderSeed = {
  paymentIntentId: string;
  buyer: string;
  status: OrderStatus;
  daysAgo: number;
  coupon?: string;
  items: { slug: string; quantity: number }[];
};
type ReviewSeed = { buyer: string; slug: string; rating: number; comment: string; daysAgo: number };

const CATEGORIES: CategorySeed[] = [
  {
    slug: 'electronics',
    name: 'Electronics',
    children: [
      { slug: 'audio', name: 'Audio' },
      { slug: 'wearables', name: 'Wearables' },
    ],
  },
  {
    slug: 'home-living',
    name: 'Home & Living',
    children: [
      { slug: 'kitchen', name: 'Kitchen' },
      { slug: 'decor', name: 'Decor' },
    ],
  },
  {
    slug: 'accessories',
    name: 'Accessories',
    children: [
      { slug: 'bags', name: 'Bags' },
      { slug: 'everyday-carry', name: 'Everyday Carry' },
    ],
  },
];

const PRODUCTS: ProductSeed[] = [
  {
    slug: 'aurora-wireless-headphones',
    name: 'Aurora Wireless Headphones',
    description:
      'Over-ear wireless headphones with adaptive noise cancelling, 40-hour battery life and a fold-flat travel design. Multipoint Bluetooth keeps them paired to your laptop and phone at once.',
    price: '2499.90',
    compareAtPrice: '2999.90',
    stock: 42,
    category: 'audio',
  },
  {
    slug: 'pulse-bluetooth-speaker',
    name: 'Pulse Bluetooth Speaker',
    description:
      'A palm-sized speaker with surprisingly deep bass, IPX7 waterproofing and 16 hours of playtime. Pair two of them for instant stereo.',
    price: '1199.50',
    stock: 58,
    category: 'audio',
  },
  {
    slug: 'echo-buds-pro',
    name: 'Echo Buds Pro',
    description:
      'True-wireless earbuds with hybrid noise cancelling, wireless charging case and an in-ear fit test that tunes the seal to your ears.',
    price: '1749.00',
    stock: 6,
    category: 'audio',
  },
  {
    slug: 'horizon-smartwatch',
    name: 'Horizon Smartwatch',
    description:
      'A 1.4-inch always-on AMOLED smartwatch with GPS, heart-rate and sleep tracking, and a battery that comfortably clears a full week.',
    price: '3299.00',
    compareAtPrice: '3799.00',
    stock: 25,
    category: 'wearables',
  },
  {
    slug: 'stride-fitness-band',
    name: 'Stride Fitness Band',
    description:
      'A featherweight fitness band that tracks steps, workouts and sleep, with a two-week battery and a bright daylight-readable display.',
    price: '899.90',
    stock: 77,
    category: 'wearables',
  },
  {
    slug: 'nova-smart-ring',
    name: 'Nova Smart Ring',
    description:
      'Discreet titanium smart ring measuring heart rate, temperature trends and recovery — a week of insight from a single charge.',
    price: '2199.00',
    stock: 14,
    category: 'wearables',
  },
  {
    slug: 'artisan-coffee-grinder',
    name: 'Artisan Coffee Grinder',
    description:
      'Conical-burr grinder with 40 grind settings from espresso-fine to French-press-coarse. Slow RPM keeps the grounds cool and the flavor intact.',
    price: '1549.90',
    stock: 33,
    category: 'kitchen',
  },
  {
    slug: 'santoku-chef-knife',
    name: 'Santoku Chef Knife',
    description:
      'A 18 cm Japanese-style santoku forged from high-carbon stainless steel, hand-finished to a razor edge and balanced by a full tang.',
    price: '1289.00',
    compareAtPrice: '1489.00',
    stock: 21,
    category: 'kitchen',
  },
  {
    slug: 'ceramic-mug-set',
    name: 'Ceramic Mug Set',
    description:
      'Four stoneware mugs in a matte two-tone glaze. Generous 350 ml capacity, dishwasher and microwave safe, stackable to save shelf space.',
    price: '449.90',
    stock: 96,
    category: 'kitchen',
  },
  {
    slug: 'cast-iron-skillet',
    name: 'Cast Iron Skillet',
    description:
      'A pre-seasoned 26 cm cast iron skillet that moves from stovetop to oven to campfire. Heats evenly, sears deeply and lasts generations.',
    price: '979.50',
    stock: 18,
    category: 'kitchen',
  },
  {
    slug: 'lumen-table-lamp',
    name: 'Lumen Table Lamp',
    description:
      'A sculptural table lamp with a warm-to-neutral dimmable LED core and a touch-sensitive base. Casts a soft, glare-free pool of light.',
    price: '749.90',
    stock: 40,
    category: 'decor',
  },
  {
    slug: 'woven-throw-blanket',
    name: 'Woven Throw Blanket',
    description:
      'A 130×170 cm throw woven from recycled cotton in a subtle herringbone pattern — heavy enough to feel substantial, light enough for summer evenings.',
    price: '559.00',
    stock: 64,
    category: 'decor',
  },
  {
    slug: 'amber-scented-candle',
    name: 'Amber Scented Candle',
    description:
      'Hand-poured soy candle with notes of amber, sandalwood and vanilla. Around 45 hours of burn time in a reusable smoked-glass jar.',
    price: '219.90',
    stock: 3,
    category: 'decor',
  },
  {
    slug: 'voyager-canvas-backpack',
    name: 'Voyager Canvas Backpack',
    description:
      'A 24 L waxed-canvas backpack with a padded 16-inch laptop sleeve, magnetic top closure and leather-trimmed straps that soften with use.',
    price: '1399.00',
    compareAtPrice: '1699.00',
    stock: 29,
    category: 'bags',
  },
  {
    slug: 'metro-messenger-bag',
    name: 'Metro Messenger Bag',
    description:
      'A slim commuter messenger in water-repellent recycled nylon with a quick-access phone pocket and a trolley strap for travel days.',
    price: '1149.90',
    stock: 12,
    category: 'bags',
  },
  {
    slug: 'slimfold-leather-wallet',
    name: 'Slimfold Leather Wallet',
    description:
      'Full-grain leather bifold that holds eight cards and folded notes while staying under a centimetre thick. RFID-shielded lining.',
    price: '489.90',
    stock: 85,
    category: 'everyday-carry',
  },
  {
    slug: 'titan-water-bottle',
    name: 'Titan Water Bottle',
    description:
      'A 750 ml double-wall insulated bottle that keeps drinks cold for 24 hours or hot for 12. Powder-coated grip and a leakproof twist cap.',
    price: '329.00',
    stock: 120,
    category: 'everyday-carry',
  },
  {
    slug: 'trek-travel-organizer',
    name: 'Trek Travel Organizer',
    description:
      'A zip-around tech organizer with elastic loops for cables, slots for cards and passports, and a padded pocket for a power bank.',
    price: '649.90',
    stock: 47,
    category: 'everyday-carry',
  },
];

const CUSTOMERS: CustomerSeed[] = [
  { email: 'ada@example.com', name: 'Ada Yılmaz', city: 'İstanbul', district: 'Kadıköy' },
  { email: 'deniz@example.com', name: 'Deniz Kaya', city: 'Ankara', district: 'Çankaya' },
  { email: 'mert@example.com', name: 'Mert Demir', city: 'İzmir', district: 'Konak' },
  { email: 'elif@example.com', name: 'Elif Şahin', city: 'Bursa', district: 'Nilüfer' },
];

// Statuses cover the whole pipeline so the admin dashboard and the mobile
// order timeline both have something real to show.
const ORDERS: OrderSeed[] = [
  {
    paymentIntentId: 'pi_seed_01',
    buyer: 'ada@example.com',
    status: OrderStatus.DELIVERED,
    daysAgo: 26,
    coupon: 'WELCOME10',
    items: [
      { slug: 'aurora-wireless-headphones', quantity: 1 },
      { slug: 'ceramic-mug-set', quantity: 2 },
    ],
  },
  {
    paymentIntentId: 'pi_seed_02',
    buyer: 'ada@example.com',
    status: OrderStatus.SHIPPED,
    daysAgo: 4,
    items: [
      { slug: 'lumen-table-lamp', quantity: 1 },
      { slug: 'woven-throw-blanket', quantity: 1 },
    ],
  },
  {
    paymentIntentId: 'pi_seed_03',
    buyer: 'deniz@example.com',
    status: OrderStatus.DELIVERED,
    daysAgo: 19,
    items: [{ slug: 'horizon-smartwatch', quantity: 1 }],
  },
  {
    paymentIntentId: 'pi_seed_04',
    buyer: 'deniz@example.com',
    status: OrderStatus.PAID,
    daysAgo: 1,
    items: [{ slug: 'echo-buds-pro', quantity: 1 }],
  },
  {
    paymentIntentId: 'pi_seed_05',
    buyer: 'mert@example.com',
    status: OrderStatus.DELIVERED,
    daysAgo: 12,
    items: [
      { slug: 'artisan-coffee-grinder', quantity: 1 },
      { slug: 'amber-scented-candle', quantity: 2 },
    ],
  },
  {
    paymentIntentId: 'pi_seed_06',
    buyer: 'mert@example.com',
    status: OrderStatus.CANCELLED,
    daysAgo: 8,
    items: [{ slug: 'voyager-canvas-backpack', quantity: 1 }],
  },
  {
    paymentIntentId: 'pi_seed_07',
    buyer: 'elif@example.com',
    status: OrderStatus.SHIPPED,
    daysAgo: 2,
    coupon: 'FIRST50',
    items: [
      { slug: 'santoku-chef-knife', quantity: 1 },
      { slug: 'cast-iron-skillet', quantity: 1 },
    ],
  },
  {
    paymentIntentId: 'pi_seed_08',
    buyer: 'elif@example.com',
    status: OrderStatus.DELIVERED,
    daysAgo: 22,
    items: [
      { slug: 'slimfold-leather-wallet', quantity: 1 },
      { slug: 'titan-water-bottle', quantity: 2 },
    ],
  },
  {
    paymentIntentId: 'pi_seed_09',
    buyer: 'ada@example.com',
    status: OrderStatus.PREPARING,
    daysAgo: 0,
    items: [{ slug: 'pulse-bluetooth-speaker', quantity: 1 }],
  },
  {
    paymentIntentId: 'pi_seed_10',
    buyer: 'deniz@example.com',
    status: OrderStatus.PENDING,
    daysAgo: 0,
    items: [{ slug: 'stride-fitness-band', quantity: 1 }],
  },
  {
    paymentIntentId: 'pi_seed_11',
    buyer: 'mert@example.com',
    status: OrderStatus.REFUNDED,
    daysAgo: 15,
    items: [{ slug: 'metro-messenger-bag', quantity: 1 }],
  },
];

// Every reviewer below has a PAID-or-later seed order containing the product,
// matching the API's verified-buyer rule.
const REVIEWS: ReviewSeed[] = [
  {
    buyer: 'ada@example.com',
    slug: 'aurora-wireless-headphones',
    rating: 5,
    comment: 'Crystal-clear sound and the battery genuinely lasts the week. Worth every lira.',
    daysAgo: 20,
  },
  {
    buyer: 'ada@example.com',
    slug: 'ceramic-mug-set',
    rating: 4,
    comment: 'Lovely glaze and a generous size — one mug arrived with a tiny chip though.',
    daysAgo: 18,
  },
  {
    buyer: 'deniz@example.com',
    slug: 'horizon-smartwatch',
    rating: 5,
    comment: 'Bright screen, accurate GPS, and I only charge it on Sundays.',
    daysAgo: 14,
  },
  {
    buyer: 'mert@example.com',
    slug: 'artisan-coffee-grinder',
    rating: 4,
    comment: 'Consistent grind at every setting. A little loud, but it is over in seconds.',
    daysAgo: 9,
  },
  {
    buyer: 'mert@example.com',
    slug: 'amber-scented-candle',
    rating: 3,
    comment: 'Smells wonderful, burns a bit faster than advertised.',
    daysAgo: 7,
  },
  {
    buyer: 'elif@example.com',
    slug: 'slimfold-leather-wallet',
    rating: 5,
    comment: 'Slim as promised and the leather already looks better with use.',
    daysAgo: 17,
  },
  {
    buyer: 'elif@example.com',
    slug: 'titan-water-bottle',
    rating: 4,
    comment: 'Ice survives a full day at the office. Wish it fit cup holders better.',
    daysAgo: 16,
  },
  {
    buyer: 'elif@example.com',
    slug: 'santoku-chef-knife',
    rating: 5,
    comment: 'Scary sharp out of the box and beautifully balanced.',
    daysAgo: 1,
  },
];

const FAVORITES: { buyer: string; slug: string }[] = [
  { buyer: 'ada@example.com', slug: 'nova-smart-ring' },
  { buyer: 'ada@example.com', slug: 'santoku-chef-knife' },
  { buyer: 'deniz@example.com', slug: 'aurora-wireless-headphones' },
  { buyer: 'elif@example.com', slug: 'woven-throw-blanket' },
  { buyer: 'elif@example.com', slug: 'voyager-canvas-backpack' },
];

const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
});

function daysAgo(days: number): Date {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000);
}

// Money math in integer cents; Decimal columns accept the string form.
function toCents(price: string): number {
  return Math.round(Number(price) * 100);
}

function toDecimalString(cents: number): string {
  return (cents / 100).toFixed(2);
}

async function seedUsers() {
  const admin = await prisma.user.upsert({
    where: { email: 'admin@example.com' },
    update: { passwordHash: await argonHash(ADMIN_PASSWORD), role: 'ADMIN' },
    create: {
      email: 'admin@example.com',
      name: 'Store Admin',
      role: 'ADMIN',
      passwordHash: await argonHash(ADMIN_PASSWORD),
    },
  });

  const customers = new Map<string, string>();
  for (const [index, customer] of CUSTOMERS.entries()) {
    const passwordHash = await argonHash(CUSTOMER_PASSWORD);
    const user = await prisma.user.upsert({
      where: { email: customer.email },
      update: { passwordHash },
      create: { email: customer.email, name: customer.name, passwordHash },
    });
    customers.set(customer.email, user.id);

    await prisma.address.upsert({
      where: { id: `addr_seed_${index + 1}` },
      update: {},
      create: {
        id: `addr_seed_${index + 1}`,
        userId: user.id,
        fullName: customer.name,
        phone: `+90 532 000 00 ${String(index + 10)}`,
        line1: `${customer.district} Mah. Demo Cad. No: ${index + 3}`,
        city: customer.city,
        district: customer.district,
        postalCode: `34${String(700 + index * 11)}`,
        isDefault: true,
      },
    });
  }

  return { adminId: admin.id, customers };
}

async function seedCatalog() {
  const categories = new Map<string, string>();
  for (const root of CATEGORIES) {
    const parent = await prisma.category.upsert({
      where: { slug: root.slug },
      update: { name: root.name },
      create: { slug: root.slug, name: root.name },
    });
    categories.set(root.slug, parent.id);
    for (const child of root.children) {
      const created = await prisma.category.upsert({
        where: { slug: child.slug },
        update: { name: child.name, parentId: parent.id },
        create: { slug: child.slug, name: child.name, parentId: parent.id },
      });
      categories.set(child.slug, created.id);
    }
  }

  const products = new Map<string, { id: string; priceCents: number; name: string }>();
  for (const product of PRODUCTS) {
    const data = {
      name: product.name,
      description: product.description,
      price: product.price,
      compareAtPrice: product.compareAtPrice ?? null,
      stock: product.stock,
      categoryId: categories.get(product.category)!,
      isActive: true,
    };
    const created = await prisma.product.upsert({
      where: { slug: product.slug },
      update: data,
      create: { slug: product.slug, ...data },
    });
    products.set(product.slug, {
      id: created.id,
      priceCents: toCents(product.price),
      name: product.name,
    });
  }

  return products;
}

// Uploads generated placeholder images to MinIO and registers them, mirroring
// the URL shape StorageService produces. If MinIO is unreachable the catalog
// still seeds — the apps render their built-in placeholders instead.
async function seedImages(products: Map<string, { id: string }>) {
  const useSsl = process.env.MINIO_USE_SSL === 'true';
  const endpoint = `${useSsl ? 'https' : 'http'}://${process.env.MINIO_ENDPOINT ?? 'localhost'}:${process.env.MINIO_PORT ?? '9000'}`;
  const bucket = process.env.MINIO_BUCKET ?? 'product-images';
  const publicBaseUrl = process.env.MINIO_PUBLIC_URL ?? endpoint;
  const client = new S3Client({
    endpoint,
    region: process.env.MINIO_REGION ?? 'us-east-1',
    forcePathStyle: true,
    credentials: {
      accessKeyId: process.env.MINIO_ROOT_USER ?? 'minioadmin',
      secretAccessKey: process.env.MINIO_ROOT_PASSWORD ?? 'minioadmin',
    },
  });

  try {
    for (const [slug, product] of products) {
      for (let variant = 0; variant < IMAGES_PER_PRODUCT; variant++) {
        const key = `products/${product.id}/seed-${variant}.png`;
        await client.send(
          new PutObjectCommand({
            Bucket: bucket,
            Key: key,
            Body: productImagePng(slug, variant),
            ContentType: 'image/png',
          }),
        );
        await prisma.productImage.upsert({
          where: { id: `img_seed_${slug}_${variant}` },
          update: { url: `${publicBaseUrl}/${bucket}/${key}` },
          create: {
            id: `img_seed_${slug}_${variant}`,
            productId: product.id,
            url: `${publicBaseUrl}/${bucket}/${key}`,
            sortOrder: variant,
          },
        });
      }
    }
    return true;
  } catch (error) {
    console.warn(
      `MinIO unreachable — skipping product images (${(error as Error).message})`,
    );
    return false;
  } finally {
    client.destroy();
  }
}

async function seedCoupons() {
  const coupons = new Map<string, string>();
  const definitions = [
    { code: 'WELCOME10', type: 'PERCENTAGE', value: '10.00', minSubtotal: '0.00', maxUses: null as number | null, expiresAt: null as Date | null },
    { code: 'FIRST50', type: 'FIXED', value: '50.00', minSubtotal: '500.00', maxUses: 100, expiresAt: null },
    // Already expired on purpose: the admin coupon list shows the state.
    { code: 'SUMMER25', type: 'PERCENTAGE', value: '25.00', minSubtotal: '750.00', maxUses: 50, expiresAt: daysAgo(10) },
  ] as const;

  for (const coupon of definitions) {
    const usedCount = ORDERS.filter(
      (order) => order.coupon === coupon.code && order.status !== OrderStatus.CANCELLED,
    ).length;
    const created = await prisma.coupon.upsert({
      where: { code: coupon.code },
      update: { usedCount },
      create: {
        code: coupon.code,
        type: coupon.type,
        value: coupon.value,
        minSubtotal: coupon.minSubtotal,
        maxUses: coupon.maxUses,
        usedCount,
        expiresAt: coupon.expiresAt,
        isActive: true,
      },
    });
    coupons.set(coupon.code, created.id);
  }
  return coupons;
}

async function seedOrders(
  customers: Map<string, string>,
  products: Map<string, { id: string; priceCents: number; name: string }>,
  coupons: Map<string, string>,
) {
  for (const order of ORDERS) {
    const subtotalCents = order.items.reduce(
      (sum, item) => sum + products.get(item.slug)!.priceCents * item.quantity,
      0,
    );
    let discountCents = 0;
    if (order.coupon === 'WELCOME10') {
      discountCents = Math.round(subtotalCents * 0.1);
    } else if (order.coupon === 'FIRST50') {
      discountCents = 5000;
    }

    const buyerId = customers.get(order.buyer)!;
    const buyerIndex = CUSTOMERS.findIndex((c) => c.email === order.buyer);
    const createdAt = daysAgo(order.daysAgo);

    await prisma.order.upsert({
      where: { stripePaymentIntentId: order.paymentIntentId },
      update: { status: order.status },
      create: {
        userId: buyerId,
        status: order.status,
        subtotal: toDecimalString(subtotalCents),
        discountTotal: toDecimalString(discountCents),
        total: toDecimalString(subtotalCents - discountCents),
        addressId: `addr_seed_${buyerIndex + 1}`,
        couponId: order.coupon ? coupons.get(order.coupon) : null,
        stripePaymentIntentId: order.paymentIntentId,
        createdAt,
        items: {
          create: order.items.map((item) => ({
            productId: products.get(item.slug)!.id,
            nameSnapshot: products.get(item.slug)!.name,
            priceSnapshot: toDecimalString(products.get(item.slug)!.priceCents),
            quantity: item.quantity,
          })),
        },
      },
    });
  }
}

async function seedReviewsAndFavorites(
  customers: Map<string, string>,
  products: Map<string, { id: string }>,
) {
  for (const review of REVIEWS) {
    const userId = customers.get(review.buyer)!;
    const productId = products.get(review.slug)!.id;
    await prisma.review.upsert({
      where: { productId_userId: { productId, userId } },
      update: { rating: review.rating, comment: review.comment },
      create: {
        productId,
        userId,
        rating: review.rating,
        comment: review.comment,
        createdAt: daysAgo(review.daysAgo),
      },
    });
  }

  for (const favorite of FAVORITES) {
    const userId = customers.get(favorite.buyer)!;
    const productId = products.get(favorite.slug)!.id;
    await prisma.favorite.upsert({
      where: { userId_productId: { userId, productId } },
      update: {},
      create: { userId, productId },
    });
  }
}

async function main() {
  const { customers } = await seedUsers();
  const products = await seedCatalog();
  const imagesUploaded = await seedImages(products);
  const coupons = await seedCoupons();
  await seedOrders(customers, products, coupons);
  await seedReviewsAndFavorites(customers, products);

  console.log('Seed complete:');
  console.log(`  users:     1 admin + ${CUSTOMERS.length} customers`);
  console.log(`  catalog:   ${CATEGORIES.length} root categories, ${PRODUCTS.length} products`);
  console.log(`  images:    ${imagesUploaded ? `${PRODUCTS.length * IMAGES_PER_PRODUCT} uploaded to MinIO` : 'skipped (MinIO unreachable)'}`);
  console.log(`  commerce:  ${ORDERS.length} orders, 3 coupons, ${REVIEWS.length} reviews, ${FAVORITES.length} favorites`);
  console.log('Demo credentials: admin@example.com / Admin123! — ada@example.com / Customer123!');
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
