"use client";

import { toast } from "sonner";
import { Loader2 } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { useDeleteCoupon } from "@/lib/coupons";
import { apiErrorMessage } from "@/lib/api";
import type { Coupon } from "@/lib/api-types";

interface Props {
  coupon: Coupon | null;
  onOpenChange: (open: boolean) => void;
}

export function DeleteCouponDialog({ coupon, onOpenChange }: Props) {
  const deleteMutation = useDeleteCoupon();
  const used = (coupon?.usedCount ?? 0) > 0;

  const onConfirm = async () => {
    if (!coupon) return;
    try {
      await deleteMutation.mutateAsync(coupon.id);
      toast.success("Coupon deleted");
      onOpenChange(false);
    } catch (error) {
      toast.error(apiErrorMessage(error, "Could not delete coupon"));
    }
  };

  return (
    <Dialog open={Boolean(coupon)} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Delete coupon</DialogTitle>
          <DialogDescription>
            This permanently removes{" "}
            <span className="font-mono font-medium text-foreground">
              {coupon?.code}
            </span>
            .{" "}
            {used
              ? "This coupon has already been used by orders, so it cannot be deleted — deactivate it instead to stop new redemptions."
              : "This cannot be undone."}
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button
            variant="destructive"
            onClick={onConfirm}
            disabled={deleteMutation.isPending || used}
          >
            {deleteMutation.isPending && (
              <Loader2 className="size-4 animate-spin" />
            )}
            Delete
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
