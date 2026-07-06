import {
  keepPreviousData,
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import { api } from "./api";
import type { AdminReview, Paginated } from "./api-types";

export interface ReviewListParams {
  productId?: string;
  page?: number;
  limit?: number;
}

const reviewKeys = {
  all: ["reviews"] as const,
  list: (params: ReviewListParams) => ["reviews", "list", params] as const,
};

export function useAdminReviews(params: ReviewListParams) {
  return useQuery({
    queryKey: reviewKeys.list(params),
    queryFn: async () => {
      const res = await api.get<Paginated<AdminReview>>("/admin/reviews", {
        params,
      });
      return res.data;
    },
    placeholderData: keepPreviousData,
  });
}

export function useDeleteReview() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      await api.delete(`/admin/reviews/${id}`);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: reviewKeys.all }),
  });
}
