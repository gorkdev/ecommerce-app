import {
  keepPreviousData,
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import { api } from "./api";
import { formatMoney } from "./format";
import type { Coupon, CouponInput, Paginated } from "./api-types";

export interface CouponListParams {
  page?: number;
  limit?: number;
}

const couponKeys = {
  all: ["coupons"] as const,
  list: (params: CouponListParams) => ["coupons", "list", params] as const,
};

export function useAdminCoupons(params: CouponListParams) {
  return useQuery({
    queryKey: couponKeys.list(params),
    queryFn: async () => {
      const res = await api.get<Paginated<Coupon>>("/admin/coupons", {
        params,
      });
      return res.data;
    },
    placeholderData: keepPreviousData,
  });
}

export function useCreateCoupon() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (input: CouponInput) => {
      const res = await api.post<Coupon>("/admin/coupons", input);
      return res.data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: couponKeys.all }),
  });
}

export function useUpdateCoupon() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      id,
      input,
    }: {
      id: string;
      input: Partial<CouponInput>;
    }) => {
      const res = await api.patch<Coupon>(`/admin/coupons/${id}`, input);
      return res.data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: couponKeys.all }),
  });
}

export function useDeleteCoupon() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      await api.delete(`/admin/coupons/${id}`);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: couponKeys.all }),
  });
}

// ---- Display helpers ----

// PERCENTAGE renders as "10%"; FIXED as a money amount (store is TRY-based —
// coupons carry no currency of their own, the order applies its cart currency).
export function formatCouponValue(coupon: Coupon): string {
  return coupon.type === "PERCENTAGE"
    ? `${Number(coupon.value)}%`
    : formatMoney(coupon.value);
}

export function isExpired(coupon: Coupon): boolean {
  return coupon.expiresAt !== null && new Date(coupon.expiresAt) < new Date();
}

export function isUsedUp(coupon: Coupon): boolean {
  return coupon.maxUses !== null && coupon.usedCount >= coupon.maxUses;
}

export function usesLabel(coupon: Coupon): string {
  return `${coupon.usedCount} / ${coupon.maxUses ?? "∞"}`;
}
