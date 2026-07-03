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
import { useDeleteProduct } from "@/lib/products";
import { apiErrorMessage } from "@/lib/api";
import type { Product } from "@/lib/api-types";

interface Props {
  product: Product | null;
  onOpenChange: (open: boolean) => void;
}

export function DeleteProductDialog({ product, onOpenChange }: Props) {
  const deleteMutation = useDeleteProduct();

  const onConfirm = async () => {
    if (!product) return;
    try {
      await deleteMutation.mutateAsync(product.id);
      toast.success("Product deleted");
      onOpenChange(false);
    } catch (error) {
      toast.error(apiErrorMessage(error, "Could not delete product"));
    }
  };

  return (
    <Dialog open={Boolean(product)} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Delete product</DialogTitle>
          <DialogDescription>
            This permanently removes{" "}
            <span className="font-medium text-foreground">{product?.name}</span>.
            This action cannot be undone.
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button
            variant="destructive"
            onClick={onConfirm}
            disabled={deleteMutation.isPending}
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
