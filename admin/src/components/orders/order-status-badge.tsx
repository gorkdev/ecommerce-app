import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import { ORDER_STATUS_META } from "@/lib/orders";
import type { OrderStatus } from "@/lib/api-types";

export function OrderStatusBadge({
  status,
  className,
}: {
  status: OrderStatus;
  className?: string;
}) {
  const meta = ORDER_STATUS_META[status];
  return (
    <Badge className={cn("border-transparent", meta.className, className)}>
      {meta.label}
    </Badge>
  );
}
