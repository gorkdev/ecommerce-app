import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import { ROLE_META } from "@/lib/users";
import type { Role } from "@/lib/api-types";

export function RoleBadge({
  role,
  className,
}: {
  role: Role;
  className?: string;
}) {
  const meta = ROLE_META[role];
  return (
    <Badge className={cn("border-transparent", meta.className, className)}>
      {meta.label}
    </Badge>
  );
}
