import { useQuery } from "@tanstack/react-query";
import { api } from "./api";
import type { DashboardStats } from "./api-types";

const statsKeys = {
  all: ["stats"] as const,
};

export function useDashboardStats() {
  return useQuery({
    queryKey: statsKeys.all,
    queryFn: async () => {
      const res = await api.get<DashboardStats>("/admin/stats");
      return res.data;
    },
  });
}
