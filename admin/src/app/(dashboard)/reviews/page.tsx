"use client";

import { useState } from "react";
import { Star } from "lucide-react";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";
import { ReviewsTable } from "@/components/reviews/reviews-table";
import { DeleteReviewDialog } from "@/components/reviews/delete-review-dialog";
import { useAdminReviews } from "@/lib/reviews";
import type { AdminReview } from "@/lib/api-types";

export default function ReviewsPage() {
  const [page, setPage] = useState(1);
  const { data, isPending, isError } = useAdminReviews({ page, limit: 20 });

  const [deleting, setDeleting] = useState<AdminReview | null>(null);

  const reviews = data?.data ?? [];
  const meta = data?.meta;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Reviews</h1>
        <p className="text-sm text-muted-foreground">
          Moderate customer reviews. Remove any that violate the store policy.
        </p>
      </div>

      {isPending ? (
        <div className="space-y-2 rounded-lg border p-4">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton key={i} className="h-11 w-full" />
          ))}
        </div>
      ) : isError ? (
        <div className="rounded-lg border border-destructive/30 bg-destructive/5 p-8 text-center text-sm text-destructive">
          Failed to load reviews. Check that the API is running.
        </div>
      ) : reviews.length === 0 ? (
        <div className="flex flex-col items-center gap-3 rounded-lg border border-dashed p-12 text-center">
          <Star className="size-8 text-muted-foreground" />
          <div>
            <p className="font-medium">No reviews yet</p>
            <p className="text-sm text-muted-foreground">
              Customer reviews will appear here once they start rating products.
            </p>
          </div>
        </div>
      ) : (
        <>
          <ReviewsTable reviews={reviews} onDelete={setDeleting} />
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

      <DeleteReviewDialog
        review={deleting}
        onOpenChange={(open) => !open && setDeleting(null)}
      />
    </div>
  );
}
