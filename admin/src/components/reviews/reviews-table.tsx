"use client";

import { Trash2 } from "lucide-react";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { formatDate } from "@/lib/format";
import { StarRating } from "./star-rating";
import type { AdminReview } from "@/lib/api-types";

interface Props {
  reviews: AdminReview[];
  onDelete: (review: AdminReview) => void;
}

export function ReviewsTable({ reviews, onDelete }: Props) {
  return (
    <div className="overflow-x-auto rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Product</TableHead>
            <TableHead>Rating</TableHead>
            <TableHead>Comment</TableHead>
            <TableHead>Author</TableHead>
            <TableHead>Date</TableHead>
            <TableHead className="w-[60px]" />
          </TableRow>
        </TableHeader>
        <TableBody>
          {reviews.map((review) => (
            <TableRow key={review.id}>
              <TableCell className="font-medium">
                {review.product.name}
                <span className="block font-mono text-xs text-muted-foreground">
                  {review.product.slug}
                </span>
              </TableCell>
              <TableCell>
                <StarRating rating={review.rating} />
              </TableCell>
              <TableCell className="max-w-xs">
                {review.comment ? (
                  <span
                    className="line-clamp-2 text-sm text-muted-foreground"
                    title={review.comment}
                  >
                    {review.comment}
                  </span>
                ) : (
                  <span className="text-xs italic text-muted-foreground/60">
                    No comment
                  </span>
                )}
              </TableCell>
              <TableCell>
                {review.user.name}
                <span className="block text-xs text-muted-foreground">
                  {review.user.email}
                </span>
              </TableCell>
              <TableCell className="text-muted-foreground">
                {formatDate(review.createdAt)}
              </TableCell>
              <TableCell>
                <Button
                  variant="ghost"
                  size="icon"
                  aria-label="Delete review"
                  onClick={() => onDelete(review)}
                >
                  <Trash2 className="size-4 text-destructive" />
                </Button>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
