"use client";

import { useState } from "react";
import { Plus, Ticket } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { CouponsTable } from "@/components/coupons/coupons-table";
import { CouponFormDialog } from "@/components/coupons/coupon-form-dialog";
import { DeleteCouponDialog } from "@/components/coupons/delete-coupon-dialog";
import { useAdminCoupons } from "@/lib/coupons";
import type { Coupon } from "@/lib/api-types";

export default function CouponsPage() {
  const [page, setPage] = useState(1);
  const { data, isPending, isError } = useAdminCoupons({ page, limit: 20 });

  const [formOpen, setFormOpen] = useState(false);
  const [editing, setEditing] = useState<Coupon | null>(null);
  const [deleting, setDeleting] = useState<Coupon | null>(null);

  const openCreate = () => {
    setEditing(null);
    setFormOpen(true);
  };
  const openEdit = (coupon: Coupon) => {
    setEditing(coupon);
    setFormOpen(true);
  };

  const coupons = data?.data ?? [];
  const meta = data?.meta;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Coupons</h1>
          <p className="text-sm text-muted-foreground">
            Create and manage discount codes for the storefront.
          </p>
        </div>
        <Button onClick={openCreate}>
          <Plus className="size-4" />
          Add coupon
        </Button>
      </div>

      {isPending ? (
        <div className="space-y-2 rounded-lg border p-4">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton key={i} className="h-11 w-full" />
          ))}
        </div>
      ) : isError ? (
        <div className="rounded-lg border border-destructive/30 bg-destructive/5 p-8 text-center text-sm text-destructive">
          Failed to load coupons. Check that the API is running.
        </div>
      ) : coupons.length === 0 ? (
        <div className="flex flex-col items-center gap-3 rounded-lg border border-dashed p-12 text-center">
          <Ticket className="size-8 text-muted-foreground" />
          <div>
            <p className="font-medium">No coupons yet</p>
            <p className="text-sm text-muted-foreground">
              Create your first discount code to run a promotion.
            </p>
          </div>
          <Button onClick={openCreate} variant="outline">
            <Plus className="size-4" />
            Add coupon
          </Button>
        </div>
      ) : (
        <>
          <CouponsTable
            coupons={coupons}
            onEdit={openEdit}
            onDelete={setDeleting}
          />
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

      <CouponFormDialog
        open={formOpen}
        onOpenChange={setFormOpen}
        coupon={editing}
      />
      <DeleteCouponDialog
        coupon={deleting}
        onOpenChange={(open) => !open && setDeleting(null)}
      />
    </div>
  );
}
