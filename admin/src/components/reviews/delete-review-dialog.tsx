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
import { StarRating } from "./star-rating";
import { useDeleteReview } from "@/lib/reviews";
import { apiErrorMessage } from "@/lib/api";
import type { AdminReview } from "@/lib/api-types";

interface Props {
  review: AdminReview | null;
  onOpenChange: (open: boolean) => void;
}

export function DeleteReviewDialog({ review, onOpenChange }: Props) {
  const deleteMutation = useDeleteReview();

  const onConfirm = async () => {
    if (!review) return;
    try {
      await deleteMutation.mutateAsync(review.id);
      toast.success("Review removed");
      onOpenChange(false);
    } catch (error) {
      toast.error(apiErrorMessage(error, "Could not remove review"));
    }
  };

  return (
    <Dialog open={Boolean(review)} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Remove review</DialogTitle>
          <DialogDescription>
            This permanently removes the review by{" "}
            <span className="font-medium text-foreground">
              {review?.user.name}
            </span>{" "}
            of{" "}
            <span className="font-medium text-foreground">
              {review?.product.name}
            </span>
            . This cannot be undone.
          </DialogDescription>
        </DialogHeader>
        {review && (
          <div className="rounded-md border bg-muted/30 p-3 text-sm">
            <StarRating rating={review.rating} />
            {review.comment && (
              <p className="mt-2 text-muted-foreground">{review.comment}</p>
            )}
          </div>
        )}
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
            Remove
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
