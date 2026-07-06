"use client";

import { ChevronRight } from "lucide-react";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { RoleBadge } from "./role-badge";
import { formatDate } from "@/lib/format";
import type { AdminUserListItem } from "@/lib/api-types";

interface Props {
  users: AdminUserListItem[];
  onView: (user: AdminUserListItem) => void;
}

export function UsersTable({ users, onView }: Props) {
  return (
    <div className="overflow-x-auto rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>User</TableHead>
            <TableHead>Role</TableHead>
            <TableHead className="text-right">Orders</TableHead>
            <TableHead className="text-right">Reviews</TableHead>
            <TableHead>Joined</TableHead>
            <TableHead className="w-[40px]" />
          </TableRow>
        </TableHeader>
        <TableBody>
          {users.map((user) => (
            <TableRow
              key={user.id}
              className="cursor-pointer"
              onClick={() => onView(user)}
            >
              <TableCell>
                <div className="font-medium">{user.name}</div>
                <div className="text-xs text-muted-foreground">
                  {user.email}
                </div>
              </TableCell>
              <TableCell>
                <RoleBadge role={user.role} />
              </TableCell>
              <TableCell className="text-right tabular-nums">
                {user._count.orders}
              </TableCell>
              <TableCell className="text-right tabular-nums text-muted-foreground">
                {user._count.reviews}
              </TableCell>
              <TableCell className="text-muted-foreground">
                {formatDate(user.createdAt)}
              </TableCell>
              <TableCell>
                <ChevronRight className="size-4 text-muted-foreground" />
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
