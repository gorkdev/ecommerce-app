import {
  keepPreviousData,
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import { api } from "./api";
import type { Paginated, Product, ProductInput } from "./api-types";

export interface ProductListParams {
  page?: number;
  limit?: number;
  search?: string;
}

const productKeys = {
  all: ["products"] as const,
  list: (params: ProductListParams) => ["products", "list", params] as const,
};

export function useAdminProducts(params: ProductListParams) {
  return useQuery({
    queryKey: productKeys.list(params),
    queryFn: async () => {
      const res = await api.get<Paginated<Product>>("/admin/products", {
        params,
      });
      return res.data;
    },
    placeholderData: keepPreviousData,
  });
}

export function useCreateProduct() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (input: ProductInput) => {
      const res = await api.post<Product>("/products", input);
      return res.data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: productKeys.all }),
  });
}

export function useUpdateProduct() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      id,
      input,
    }: {
      id: string;
      input: Partial<ProductInput>;
    }) => {
      const res = await api.patch<Product>(`/products/${id}`, input);
      return res.data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: productKeys.all }),
  });
}

export function useDeleteProduct() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      await api.delete(`/products/${id}`);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: productKeys.all }),
  });
}
