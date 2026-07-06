import {
  keepPreviousData,
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import { api } from "./api";
import type {
  AdminUserDetail,
  AdminUserListItem,
  Paginated,
  Role,
} from "./api-types";

export interface UserListParams {
  search?: string;
  role?: Role;
  page?: number;
  limit?: number;
}

const userKeys = {
  all: ["users"] as const,
  list: (params: UserListParams) => ["users", "list", params] as const,
  detail: (id: string) => ["users", "detail", id] as const,
};

export function useAdminUsers(params: UserListParams) {
  return useQuery({
    queryKey: userKeys.list(params),
    queryFn: async () => {
      const res = await api.get<Paginated<AdminUserListItem>>("/admin/users", {
        params,
      });
      return res.data;
    },
    placeholderData: keepPreviousData,
  });
}

export function useAdminUser(id: string | null) {
  return useQuery({
    queryKey: userKeys.detail(id ?? ""),
    queryFn: async () => {
      const res = await api.get<AdminUserDetail>(`/admin/users/${id}`);
      return res.data;
    },
    enabled: Boolean(id),
  });
}

export function useUpdateUserRole() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, role }: { id: string; role: Role }) => {
      const res = await api.patch<AdminUserListItem>(
        `/admin/users/${id}/role`,
        { role },
      );
      return res.data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: userKeys.all }),
  });
}

// Presentation metadata per role; kept in the same Tailwind vocabulary as the
// order/coupon badges so light and dark both read cleanly.
export const ROLE_META: Record<Role, { label: string; className: string }> = {
  ADMIN: {
    label: "Admin",
    className:
      "bg-violet-100 text-violet-700 dark:bg-violet-500/15 dark:text-violet-400",
  },
  CUSTOMER: {
    label: "Customer",
    className: "bg-muted text-muted-foreground",
  },
};

export const ROLES: Role[] = ["CUSTOMER", "ADMIN"];
