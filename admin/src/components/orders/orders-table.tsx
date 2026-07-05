"use client";

import { ChevronRight } from "lucide-react";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { OrderStatusBadge } from "./order-status-badge";
import { formatMoney, formatDate } from "@/lib/format";
import type { Order } from "@/lib/api-types";

interface Props {
  orders: Order[];
  onView: (order: Order) => void;
}

function itemCount(order: Order): number {
  return order.items.reduce((sum, item) => sum + item.quantity, 0);
}

export function OrdersTable({ orders, onView }: Props) {
  return (
    <div className="overflow-x-auto rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Order</TableHead>
            <TableHead>Customer</TableHead>
            <TableHead>Placed</TableHead>
            <TableHead className="text-right">Items</TableHead>
            <TableHead className="text-right">Total</TableHead>
            <TableHead>Status</TableHead>
            <TableHead className="w-[40px]" />
          </TableRow>
        </TableHeader>
        <TableBody>
          {orders.map((order) => (
            <TableRow
              key={order.id}
              className="cursor-pointer"
              onClick={() => onView(order)}
            >
              <TableCell className="font-mono text-xs text-muted-foreground">
                #{order.id.slice(-8)}
              </TableCell>
              <TableCell>
                <div className="font-medium">{order.user?.name ?? "—"}</div>
                <div className="text-xs text-muted-foreground">
                  {order.user?.email ?? "—"}
                </div>
              </TableCell>
              <TableCell className="text-muted-foreground">
                {formatDate(order.createdAt)}
              </TableCell>
              <TableCell className="text-right tabular-nums">
                {itemCount(order)}
              </TableCell>
              <TableCell className="text-right tabular-nums font-medium">
                {formatMoney(order.total, order.currency)}
              </TableCell>
              <TableCell>
                <OrderStatusBadge status={order.status} />
              </TableCell>
              <TableCell>
                <ChevronRight className="size-4 text-muted-foreground" />
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
