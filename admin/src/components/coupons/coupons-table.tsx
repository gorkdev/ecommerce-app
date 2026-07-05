"use client";

import { MoreHorizontal, Pencil, Trash2 } from "lucide-react";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { formatMoney, formatDate } from "@/lib/format";
import {
  formatCouponValue,
  isExpired,
  isUsedUp,
  usesLabel,
} from "@/lib/coupons";
import type { Coupon } from "@/lib/api-types";

interface Props {
  coupons: Coupon[];
  onEdit: (coupon: Coupon) => void;
  onDelete: (coupon: Coupon) => void;
}

function CouponStatus({ coupon }: { coupon: Coupon }) {
  if (!coupon.isActive) {
    return <Badge variant="secondary">Inactive</Badge>;
  }
  if (isExpired(coupon)) {
    return (
      <Badge className="border-transparent bg-rose-100 text-rose-700 dark:bg-rose-500/15 dark:text-rose-400">
        Expired
      </Badge>
    );
  }
  if (isUsedUp(coupon)) {
    return (
      <Badge className="border-transparent bg-amber-100 text-amber-700 dark:bg-amber-500/15 dark:text-amber-400">
        Used up
      </Badge>
    );
  }
  return (
    <Badge className="border-transparent bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-400">
      Active
    </Badge>
  );
}

export function CouponsTable({ coupons, onEdit, onDelete }: Props) {
  return (
    <div className="overflow-x-auto rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Code</TableHead>
            <TableHead>Discount</TableHead>
            <TableHead className="text-right">Min. subtotal</TableHead>
            <TableHead className="text-right">Uses</TableHead>
            <TableHead>Expires</TableHead>
            <TableHead>Status</TableHead>
            <TableHead className="w-[60px]" />
          </TableRow>
        </TableHeader>
        <TableBody>
          {coupons.map((coupon) => (
            <TableRow key={coupon.id}>
              <TableCell className="font-mono font-medium">
                {coupon.code}
              </TableCell>
              <TableCell>
                <span className="font-medium">
                  {formatCouponValue(coupon)}
                </span>{" "}
                <span className="text-xs text-muted-foreground">
                  {coupon.type === "PERCENTAGE" ? "off" : "fixed"}
                </span>
              </TableCell>
              <TableCell className="text-right tabular-nums text-muted-foreground">
                {Number(coupon.minSubtotal) > 0
                  ? formatMoney(coupon.minSubtotal)
                  : "—"}
              </TableCell>
              <TableCell className="text-right tabular-nums text-muted-foreground">
                {usesLabel(coupon)}
              </TableCell>
              <TableCell className="text-muted-foreground">
                {coupon.expiresAt ? formatDate(coupon.expiresAt) : "Never"}
              </TableCell>
              <TableCell>
                <CouponStatus coupon={coupon} />
              </TableCell>
              <TableCell>
                <DropdownMenu>
                  <DropdownMenuTrigger
                    render={
                      <Button variant="ghost" size="icon">
                        <MoreHorizontal className="size-4" />
                      </Button>
                    }
                  />
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem onClick={() => onEdit(coupon)}>
                      <Pencil className="size-4" />
                      Edit
                    </DropdownMenuItem>
                    <DropdownMenuItem
                      variant="destructive"
                      onClick={() => onDelete(coupon)}
                    >
                      <Trash2 className="size-4" />
                      Delete
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
