import {
  keepPreviousData,
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import { api } from "./api";
import type { Order, OrderStatus, Paginated } from "./api-types";

export interface OrderListParams {
  status?: OrderStatus;
  page?: number;
  limit?: number;
}

const orderKeys = {
  all: ["orders"] as const,
  list: (params: OrderListParams) => ["orders", "list", params] as const,
};

export function useAdminOrders(params: OrderListParams) {
  return useQuery({
    queryKey: orderKeys.list(params),
    queryFn: async () => {
      const res = await api.get<Paginated<Order>>("/admin/orders", { params });
      return res.data;
    },
    placeholderData: keepPreviousData,
  });
}

export function useUpdateOrderStatus() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      id,
      status,
    }: {
      id: string;
      status: OrderStatus;
    }) => {
      const res = await api.patch<Order>(`/admin/orders/${id}/status`, {
        status,
      });
      return res.data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: orderKeys.all }),
  });
}

// Presentation metadata per status. `className` colors the badge; kept in the
// same Tailwind vocabulary so light/dark both read cleanly.
export const ORDER_STATUS_META: Record<
  OrderStatus,
  { label: string; className: string }
> = {
  PENDING: {
    label: "Pending",
    className:
      "bg-amber-100 text-amber-700 dark:bg-amber-500/15 dark:text-amber-400",
  },
  PAID: {
    label: "Paid",
    className:
      "bg-blue-100 text-blue-700 dark:bg-blue-500/15 dark:text-blue-400",
  },
  PREPARING: {
    label: "Preparing",
    className:
      "bg-violet-100 text-violet-700 dark:bg-violet-500/15 dark:text-violet-400",
  },
  SHIPPED: {
    label: "Shipped",
    className:
      "bg-cyan-100 text-cyan-700 dark:bg-cyan-500/15 dark:text-cyan-400",
  },
  DELIVERED: {
    label: "Delivered",
    className:
      "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-400",
  },
  CANCELLED: {
    label: "Cancelled",
    className: "bg-muted text-muted-foreground",
  },
  REFUNDED: {
    label: "Refunded",
    className:
      "bg-rose-100 text-rose-700 dark:bg-rose-500/15 dark:text-rose-400",
  },
};

// Order the filter chips follow the natural fulfilment lifecycle.
export const ORDER_STATUSES: OrderStatus[] = [
  "PENDING",
  "PAID",
  "PREPARING",
  "SHIPPED",
  "DELIVERED",
  "CANCELLED",
  "REFUNDED",
];

// Mirror of the server's ALLOWED_TRANSITIONS (order.service.ts). The UI only
// offers legal next states; the API is still the source of truth and rejects
// anything illegal, so a stale mirror fails safe.
const ALLOWED_TRANSITIONS: Record<OrderStatus, OrderStatus[]> = {
  PENDING: ["PAID", "CANCELLED"],
  PAID: ["PREPARING", "CANCELLED", "REFUNDED"],
  PREPARING: ["SHIPPED", "CANCELLED"],
  SHIPPED: ["DELIVERED"],
  DELIVERED: ["REFUNDED"],
  CANCELLED: [],
  REFUNDED: [],
};

export function nextStatuses(status: OrderStatus): OrderStatus[] {
  return ALLOWED_TRANSITIONS[status];
}
