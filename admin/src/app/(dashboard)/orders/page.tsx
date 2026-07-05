"use client";

import { useEffect, useState } from "react";
import { ShoppingCart, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";
import { OrdersTable } from "@/components/orders/orders-table";
import { OrderDetailDialog } from "@/components/orders/order-detail-dialog";
import { useAdminOrders, ORDER_STATUSES, ORDER_STATUS_META } from "@/lib/orders";
import type { Order, OrderStatus } from "@/lib/api-types";

export default function OrdersPage() {
  const [status, setStatus] = useState<OrderStatus | "ALL">("ALL");
  const [page, setPage] = useState(1);
  const [viewing, setViewing] = useState<Order | null>(null);

  // A new filter always restarts at the first page.
  useEffect(() => {
    setPage(1);
  }, [status]);

  const { data, isPending, isError, isFetching } = useAdminOrders({
    status: status === "ALL" ? undefined : status,
    page,
    limit: 20,
  });

  const orders = data?.data ?? [];
  const meta = data?.meta;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Orders</h1>
        <p className="text-sm text-muted-foreground">
          Track fulfilment and move orders through their lifecycle.
        </p>
      </div>

      {/* Status filter */}
      <div className="flex flex-wrap items-center gap-2">
        <FilterChip
          label="All"
          active={status === "ALL"}
          onClick={() => setStatus("ALL")}
        />
        {ORDER_STATUSES.map((s) => (
          <FilterChip
            key={s}
            label={ORDER_STATUS_META[s].label}
            active={status === s}
            onClick={() => setStatus(s)}
          />
        ))}
        {isFetching && !isPending && (
          <Loader2 className="size-4 animate-spin text-muted-foreground" />
        )}
      </div>

      {isPending ? (
        <div className="space-y-2 rounded-lg border p-4">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-12 w-full" />
          ))}
        </div>
      ) : isError ? (
        <div className="rounded-lg border border-destructive/30 bg-destructive/5 p-8 text-center text-sm text-destructive">
          Failed to load orders. Check that the API is running.
        </div>
      ) : orders.length === 0 ? (
        <div className="flex flex-col items-center gap-3 rounded-lg border border-dashed p-12 text-center">
          <ShoppingCart className="size-8 text-muted-foreground" />
          <div>
            <p className="font-medium">No orders found</p>
            <p className="text-sm text-muted-foreground">
              {status === "ALL"
                ? "Orders will appear here once customers check out."
                : "No orders in this status."}
            </p>
          </div>
        </div>
      ) : (
        <>
          <OrdersTable orders={orders} onView={setViewing} />
          {meta && (
            <div className="flex items-center justify-between text-sm text-muted-foreground">
              <span>
                Page {meta.page} of {meta.totalPages || 1} · {meta.total} total
              </span>
              <div className="flex gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  disabled={page <= 1}
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                >
                  Previous
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  disabled={page >= (meta.totalPages || 1)}
                  onClick={() => setPage((p) => p + 1)}
                >
                  Next
                </Button>
              </div>
            </div>
          )}
        </>
      )}

      <OrderDetailDialog
        order={viewing}
        onOpenChange={(open) => !open && setViewing(null)}
      />
    </div>
  );
}

function FilterChip({
  label,
  active,
  onClick,
}: {
  label: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "rounded-full border px-3 py-1 text-sm transition-colors",
        active
          ? "border-primary bg-primary text-primary-foreground"
          : "border-input text-muted-foreground hover:bg-muted",
      )}
    >
      {label}
    </button>
  );
}
