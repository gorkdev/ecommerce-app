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
import { useDeleteCategory } from "@/lib/categories";
import { apiErrorMessage } from "@/lib/api";
import type { CategoryNode } from "@/lib/api-types";

interface Props {
  category: CategoryNode | null;
  onOpenChange: (open: boolean) => void;
}

export function DeleteCategoryDialog({ category, onOpenChange }: Props) {
  const deleteMutation = useDeleteCategory();
  const childCount = category?.children?.length ?? 0;

  const onConfirm = async () => {
    if (!category) return;
    try {
      await deleteMutation.mutateAsync(category.id);
      toast.success("Category deleted");
      onOpenChange(false);
    } catch (error) {
      toast.error(apiErrorMessage(error, "Could not delete category"));
    }
  };

  return (
    <Dialog open={Boolean(category)} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Delete category</DialogTitle>
          <DialogDescription>
            This permanently removes{" "}
            <span className="font-medium text-foreground">
              {category?.name}
            </span>
            .
            {childCount > 0 &&
              ` Its ${childCount} subcategor${
                childCount === 1 ? "y" : "ies"
              } will be moved to the top level.`}{" "}
            A category with products cannot be deleted.
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
