"use client";

import Link from "next/link";
import {
  Wallet,
  ShoppingCart,
  Users,
  AlertTriangle,
  ArrowRight,
  PackageX,
} from "lucide-react";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";
import { StatCard } from "@/components/dashboard/stat-card";
import { OrderStatusBadge } from "@/components/orders/order-status-badge";
import { useDashboardStats } from "@/lib/stats";
import { ORDER_STATUSES, ORDER_STATUS_META } from "@/lib/orders";
import { formatMoney, formatDate } from "@/lib/format";

export default function DashboardPage() {
  const { data, isPending, isError } = useDashboardStats();

  if (isError) {
    return (
      <div className="space-y-6">
        <Header />
        <div className="rounded-lg border border-destructive/30 bg-destructive/5 p-8 text-center text-sm text-destructive">
          Failed to load dashboard. Check that the API is running.
        </div>
      </div>
    );
  }

  if (isPending) {
    return (
      <div className="space-y-6">
        <Header />
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-28 w-full rounded-xl" />
          ))}
        </div>
        <Skeleton className="h-24 w-full rounded-xl" />
        <div className="grid gap-4 lg:grid-cols-2">
          <Skeleton className="h-64 w-full rounded-xl" />
          <Skeleton className="h-64 w-full rounded-xl" />
        </div>
      </div>
    );
  }

  const { revenue, counts, ordersByStatus, recentOrders, lowStockProducts } =
    data;

  return (
    <div className="space-y-6">
      <Header />

      {/* Headline KPIs */}
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          icon={Wallet}
          label="Revenue"
          value={formatMoney(revenue.total, revenue.currency)}
          hint="Paid orders, net of refunds"
        />
        <StatCard
          icon={ShoppingCart}
          label="Orders"
          value={String(counts.orders)}
          hint={`${counts.pendingOrders} awaiting payment`}
        />
        <StatCard
          icon={Users}
          label="Customers"
          value={String(counts.users)}
          hint="Registered accounts"
        />
        <StatCard
          icon={AlertTriangle}
          label="Low stock"
          value={String(counts.lowStock)}
          hint="Active products under 5 units"
          emphasis={counts.lowStock > 0}
        />
      </div>

      {/* Order pipeline */}
      <Card>
        <CardHeader>
          <CardTitle>Order pipeline</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-7">
            {ORDER_STATUSES.map((status) => (
              <div
                key={status}
                className="flex flex-col gap-1 rounded-lg border bg-muted/30 px-3 py-2"
              >
                <span className="text-xl font-semibold tabular-nums">
                  {ordersByStatus[status]}
                </span>
                <span
                  className={cn(
                    "inline-flex w-fit rounded-full px-2 py-0.5 text-xs font-medium",
                    ORDER_STATUS_META[status].className,
                  )}
                >
                  {ORDER_STATUS_META[status].label}
                </span>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-2">
        {/* Recent orders */}
        <Card>
          <CardHeader className="flex-row items-center justify-between">
            <CardTitle>Recent orders</CardTitle>
            <Link
              href="/orders"
              className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
            >
              View all <ArrowRight className="size-3.5" />
            </Link>
          </CardHeader>
          <CardContent>
            {recentOrders.length === 0 ? (
              <p className="py-6 text-center text-sm text-muted-foreground">
                No orders yet.
              </p>
            ) : (
              <div className="divide-y">
                {recentOrders.map((order) => (
                  <div
                    key={order.id}
                    className="flex items-center justify-between gap-3 py-2.5 text-sm"
                  >
                    <div className="min-w-0">
                      <p className="truncate font-medium">
                        {order.user?.name ?? "Unknown customer"}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {formatDate(order.createdAt)}
                      </p>
                    </div>
                    <OrderStatusBadge status={order.status} />
                    <span className="w-24 text-right font-medium tabular-nums">
                      {formatMoney(order.total, order.currency)}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Low stock */}
        <Card>
          <CardHeader className="flex-row items-center justify-between">
            <CardTitle>Low stock</CardTitle>
            <Link
              href="/products"
              className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
            >
              Manage <ArrowRight className="size-3.5" />
            </Link>
          </CardHeader>
          <CardContent>
            {lowStockProducts.length === 0 ? (
              <div className="flex flex-col items-center gap-2 py-6 text-center text-sm text-muted-foreground">
                <PackageX className="size-6" />
                Every active product is well stocked.
              </div>
            ) : (
              <div className="divide-y">
                {lowStockProducts.map((product) => (
                  <div
                    key={product.id}
                    className="flex items-center justify-between gap-3 py-2.5 text-sm"
                  >
                    <div className="min-w-0">
                      <p className="truncate font-medium">{product.name}</p>
                      <p className="truncate font-mono text-xs text-muted-foreground">
                        {product.slug}
                      </p>
                    </div>
                    <span
                      className={cn(
                        "rounded-full px-2 py-0.5 text-xs font-medium tabular-nums",
                        product.stock === 0
                          ? "bg-rose-100 text-rose-700 dark:bg-rose-500/15 dark:text-rose-400"
                          : "bg-amber-100 text-amber-700 dark:bg-amber-500/15 dark:text-amber-400",
                      )}
                    >
                      {product.stock} left
                    </span>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function Header() {
  return (
    <div>
      <h1 className="text-2xl font-semibold tracking-tight">Dashboard</h1>
      <p className="text-sm text-muted-foreground">
        An at-a-glance snapshot of the store.
      </p>
    </div>
  );
}
