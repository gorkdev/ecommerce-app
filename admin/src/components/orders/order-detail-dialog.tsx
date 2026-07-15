"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Loader2, ImageOff, MapPin, Ticket } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { OrderStatusBadge } from "./order-status-badge";
import {
  ORDER_STATUS_META,
  nextStatuses,
  useUpdateOrderStatus,
} from "@/lib/orders";
import { formatMoney, formatDate } from "@/lib/format";
import { apiErrorMessage } from "@/lib/api";
import type { Order, OrderStatus } from "@/lib/api-types";

interface Props {
  order: Order | null;
  onOpenChange: (open: boolean) => void;
}

export function OrderDetailDialog({ order, onOpenChange }: Props) {
  return (
    <Dialog open={Boolean(order)} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-2xl">
        {/* Keyed by order: switching orders remounts the body, so its local
            status state re-initializes without any syncing effect. */}
        {order && <OrderDetailBody key={order.id} order={order} />}
      </DialogContent>
    </Dialog>
  );
}

function OrderDetailBody({ order }: { order: Order }) {
  const updateMutation = useUpdateOrderStatus();
  // Track status locally so the badge + available transitions refresh in place
  // after an update, without waiting on the list refetch or closing the dialog.
  const [status, setStatus] = useState<OrderStatus>(order.status);
  const [target, setTarget] = useState<OrderStatus | "">("");

  const options = nextStatuses(status);

  const onUpdate = async () => {
    if (!target) return;
    try {
      const updated = await updateMutation.mutateAsync({
        id: order.id,
        status: target,
      });
      setStatus(updated.status);
      setTarget("");
      toast.success(`Order marked ${ORDER_STATUS_META[updated.status].label}`);
    } catch (error) {
      toast.error(apiErrorMessage(error, "Could not update order status"));
    }
  };

  const discount = Number(order.discountTotal);

  return (
    <>
      <DialogHeader>
        <div className="flex items-center gap-3">
          <DialogTitle className="font-mono text-base">
            #{order.id.slice(-8)}
          </DialogTitle>
          <OrderStatusBadge status={status} />
        </div>
        <DialogDescription>
          Placed {formatDate(order.createdAt)} · {order.user?.name ?? "—"} (
          {order.user?.email ?? "—"})
        </DialogDescription>
      </DialogHeader>

      {/* Line items */}
      <div className="space-y-3">
        {order.items.map((item) => {
          const image = item.product?.images?.[0];
          const line = Number(item.priceSnapshot) * item.quantity;
          return (
            <div key={item.id} className="flex items-center gap-3">
              {image ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={image.url}
                  alt={item.nameSnapshot}
                  className="size-12 shrink-0 rounded-md object-cover"
                />
              ) : (
                <div className="flex size-12 shrink-0 items-center justify-center rounded-md bg-muted text-muted-foreground">
                  <ImageOff className="size-4" />
                </div>
              )}
              <div className="min-w-0 flex-1">
                <p className="truncate font-medium">{item.nameSnapshot}</p>
                <p className="text-sm text-muted-foreground">
                  {item.quantity} ×{" "}
                  {formatMoney(item.priceSnapshot, order.currency)}
                </p>
              </div>
              <span className="tabular-nums font-medium">
                {formatMoney(line, order.currency)}
              </span>
            </div>
          );
        })}
      </div>

      <Separator />

      {/* Totals */}
      <div className="space-y-1.5 text-sm">
        <div className="flex justify-between text-muted-foreground">
          <span>Subtotal</span>
          <span className="tabular-nums">
            {formatMoney(order.subtotal, order.currency)}
          </span>
        </div>
        {discount > 0 && (
          <div className="flex justify-between text-emerald-600 dark:text-emerald-400">
            <span className="flex items-center gap-1.5">
              <Ticket className="size-3.5" />
              Discount
              {order.coupon && (
                <span className="font-mono text-xs">{order.coupon.code}</span>
              )}
            </span>
            <span className="tabular-nums">
              −{formatMoney(order.discountTotal, order.currency)}
            </span>
          </div>
        )}
        <div className="flex justify-between text-base font-semibold">
          <span>Total</span>
          <span className="tabular-nums">
            {formatMoney(order.total, order.currency)}
          </span>
        </div>
      </div>

      {/* Shipping address */}
      <div className="rounded-lg border bg-muted/30 p-3 text-sm">
        <div className="mb-1 flex items-center gap-1.5 font-medium">
          <MapPin className="size-3.5" />
          Shipping address
        </div>
        {order.address ? (
          <div className="text-muted-foreground">
            <p className="text-foreground">{order.address.fullName}</p>
            <p>{order.address.phone}</p>
            <p>
              {order.address.line1}
              {order.address.line2 ? `, ${order.address.line2}` : ""}
            </p>
            <p>
              {order.address.district}, {order.address.city}{" "}
              {order.address.postalCode}
            </p>
            <p>{order.address.country}</p>
          </div>
        ) : (
          <p className="text-muted-foreground">No address on file.</p>
        )}
      </div>

      {/* Status transition */}
      <Separator />
      <div className="space-y-2">
        <p className="text-sm font-medium">Update status</p>
        {options.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            This order is in a final state and cannot be advanced.
          </p>
        ) : (
          <div className="flex flex-wrap items-center gap-2">
            <select
              className="flex h-9 flex-1 min-w-40 rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-xs outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
              value={target}
              onChange={(e) => setTarget(e.target.value as OrderStatus | "")}
            >
              <option value="">Select a new status…</option>
              {options.map((s) => (
                <option key={s} value={s}>
                  {ORDER_STATUS_META[s].label}
                </option>
              ))}
            </select>
            <Button
              onClick={onUpdate}
              disabled={!target || updateMutation.isPending}
            >
              {updateMutation.isPending && (
                <Loader2 className="size-4 animate-spin" />
              )}
              Update
            </Button>
          </div>
        )}
      </div>
    </>
  );
}
