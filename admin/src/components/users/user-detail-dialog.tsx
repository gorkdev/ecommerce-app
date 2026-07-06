"use client";

import { useEffect, useState } from "react";
import { toast } from "sonner";
import { Loader2, ShoppingCart, Star } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { Skeleton } from "@/components/ui/skeleton";
import { RoleBadge } from "./role-badge";
import { OrderStatusBadge } from "@/components/orders/order-status-badge";
import { useAuth } from "@/components/auth-provider";
import { ROLE_META, ROLES, useAdminUser, useUpdateUserRole } from "@/lib/users";
import { formatMoney, formatDate } from "@/lib/format";
import { apiErrorMessage } from "@/lib/api";
import type { AdminUserListItem, Role } from "@/lib/api-types";

interface Props {
  user: AdminUserListItem | null;
  onOpenChange: (open: boolean) => void;
}

function Stat({
  icon: Icon,
  label,
  value,
}: {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  value: number;
}) {
  return (
    <div className="flex items-center gap-2 rounded-lg border bg-muted/30 px-3 py-2">
      <Icon className="size-4 text-muted-foreground" />
      <div>
        <p className="text-sm font-semibold tabular-nums">{value}</p>
        <p className="text-xs text-muted-foreground">{label}</p>
      </div>
    </div>
  );
}

export function UserDetailDialog({ user, onOpenChange }: Props) {
  const { user: me } = useAuth();
  const { data: detail, isPending } = useAdminUser(user?.id ?? null);
  const updateMutation = useUpdateUserRole();

  const [target, setTarget] = useState<Role | "">("");
  useEffect(() => {
    setTarget("");
  }, [user]);

  const currentRole: Role = detail?.role ?? user?.role ?? "CUSTOMER";
  const selected: Role = target || currentRole;
  const isSelf = Boolean(me && user && me.id === user.id);
  const canUpdate = selected !== currentRole && !isSelf;

  const onUpdate = async () => {
    if (!user || !canUpdate) return;
    try {
      const updated = await updateMutation.mutateAsync({
        id: user.id,
        role: selected,
      });
      setTarget("");
      toast.success(`Role changed to ${ROLE_META[updated.role].label}`);
    } catch (error) {
      toast.error(apiErrorMessage(error, "Could not change role"));
    }
  };

  return (
    <Dialog open={Boolean(user)} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-lg">
        {user && (
          <>
            <DialogHeader>
              <div className="flex items-center gap-3">
                <DialogTitle>{user.name}</DialogTitle>
                <RoleBadge role={currentRole} />
              </div>
              <DialogDescription>
                {user.email} · Joined {formatDate(user.createdAt)}
              </DialogDescription>
            </DialogHeader>

            {/* Activity */}
            <div className="grid grid-cols-2 gap-2">
              <Stat
                icon={ShoppingCart}
                label="Orders"
                value={detail?._count.orders ?? user._count.orders}
              />
              <Stat
                icon={Star}
                label="Reviews"
                value={detail?._count.reviews ?? user._count.reviews}
              />
            </div>

            {/* Recent orders */}
            <div className="space-y-2">
              <p className="text-sm font-medium">Recent orders</p>
              {isPending ? (
                <Skeleton className="h-16 w-full" />
              ) : detail && detail.orders.length > 0 ? (
                <div className="divide-y rounded-lg border">
                  {detail.orders.map((order) => (
                    <div
                      key={order.id}
                      className="flex items-center justify-between gap-3 px-3 py-2 text-sm"
                    >
                      <span className="font-mono text-xs text-muted-foreground">
                        #{order.id.slice(-8)}
                      </span>
                      <span className="text-muted-foreground">
                        {formatDate(order.createdAt)}
                      </span>
                      <OrderStatusBadge status={order.status} />
                      <span className="tabular-nums font-medium">
                        {formatMoney(order.total, order.currency)}
                      </span>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-sm text-muted-foreground">
                  This user has not placed any orders yet.
                </p>
              )}
            </div>

            {/* Role management */}
            <Separator />
            <div className="space-y-2">
              <p className="text-sm font-medium">Role</p>
              {isSelf ? (
                <p className="text-sm text-muted-foreground">
                  You cannot change your own role.
                </p>
              ) : (
                <div className="flex flex-wrap items-center gap-2">
                  <select
                    className="flex h-9 flex-1 min-w-40 rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-xs outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
                    value={selected}
                    onChange={(e) => setTarget(e.target.value as Role)}
                  >
                    {ROLES.map((r) => (
                      <option key={r} value={r}>
                        {ROLE_META[r].label}
                      </option>
                    ))}
                  </select>
                  <Button
                    onClick={onUpdate}
                    disabled={!canUpdate || updateMutation.isPending}
                  >
                    {updateMutation.isPending && (
                      <Loader2 className="size-4 animate-spin" />
                    )}
                    Update
                  </Button>
                </div>
              )}
            </div>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}
