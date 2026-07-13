import { OrderStatus } from '../generated/prisma/client';

export interface PushText {
  title: string;
  body: string;
}

// Notification copy rendered server-side in the language each device
// registered with (the API cannot ask the OS at delivery time, unlike the
// app's own ARB-driven strings). PENDING deliberately has no entry: it is
// the state an order is born in, not a change worth waking a phone for.
const ORDER_STATUS_MESSAGES: Record<
  string,
  Partial<Record<OrderStatus, PushText>>
> = {
  en: {
    PAID: {
      title: 'Payment received',
      body: 'Your order is confirmed. We are getting it ready.',
    },
    PREPARING: {
      title: 'Order update',
      body: 'Your order is being prepared.',
    },
    SHIPPED: {
      title: 'Order shipped',
      body: 'Your order is on its way.',
    },
    DELIVERED: {
      title: 'Order delivered',
      body: 'Your order has been delivered.',
    },
    CANCELLED: {
      title: 'Order cancelled',
      body: 'Your order has been cancelled.',
    },
    REFUNDED: {
      title: 'Order refunded',
      body: 'Your order has been refunded.',
    },
  },
  tr: {
    PAID: {
      title: 'Ödeme alındı',
      body: 'Siparişiniz onaylandı, hazırlamaya başlıyoruz.',
    },
    PREPARING: {
      title: 'Sipariş güncellendi',
      body: 'Siparişiniz hazırlanıyor.',
    },
    SHIPPED: {
      title: 'Sipariş kargoda',
      body: 'Siparişiniz yola çıktı.',
    },
    DELIVERED: {
      title: 'Sipariş teslim edildi',
      body: 'Siparişiniz teslim edildi.',
    },
    CANCELLED: {
      title: 'Sipariş iptal edildi',
      body: 'Siparişiniz iptal edildi.',
    },
    REFUNDED: {
      title: 'Sipariş iade edildi',
      body: 'Siparişinizin ücreti iade edildi.',
    },
  },
};

// Unknown locales fall back to English; statuses without copy return null
// (meaning: send nothing).
export function orderStatusMessage(
  locale: string,
  status: OrderStatus,
): PushText | null {
  const catalog = ORDER_STATUS_MESSAGES[locale] ?? ORDER_STATUS_MESSAGES.en;
  return catalog[status] ?? ORDER_STATUS_MESSAGES.en[status] ?? null;
}
