import {
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import { api } from "./api";
import type { Category, CategoryInput, CategoryNode } from "./api-types";

export interface CategoryOption {
  id: string;
  label: string;
}

export interface FlatCategory {
  node: CategoryNode;
  depth: number;
}

// Depth-first flatten of the category forest, preserving parent→child order.
export function flattenTree(nodes: CategoryNode[], depth = 0): FlatCategory[] {
  return nodes.flatMap((node) => [
    { node, depth },
    ...flattenTree(node.children ?? [], depth + 1),
  ]);
}

// Every id in the subtree rooted at `node` (inclusive). Used to keep a category
// from being re-parented under itself or one of its descendants.
export function subtreeIds(node: CategoryNode): string[] {
  return [node.id, ...(node.children ?? []).flatMap(subtreeIds)];
}

// Prefix key: mutations invalidate ["categories"], which also refreshes the
// derived options list consumed by the product form.
const categoryKeys = {
  all: ["categories"] as const,
  tree: ["categories", "tree"] as const,
  options: ["categories", "options"] as const,
};

export function useCategoryTree() {
  return useQuery({
    queryKey: categoryKeys.tree,
    queryFn: async () => {
      const res = await api.get<CategoryNode[]>("/categories");
      return res.data;
    },
  });
}

// The public /categories endpoint returns a forest; flatten it into indented
// options ("  Child") for a <select>.
export function useCategoryOptions() {
  return useQuery({
    queryKey: categoryKeys.options,
    queryFn: async () => {
      const res = await api.get<CategoryNode[]>("/categories");
      return flattenTree(res.data).map<CategoryOption>(({ node, depth }) => ({
        id: node.id,
        label: `${"  ".repeat(depth)}${node.name}`,
      }));
    },
  });
}

export function useCreateCategory() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (input: CategoryInput) => {
      const res = await api.post<Category>("/categories", input);
      return res.data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: categoryKeys.all }),
  });
}

export function useUpdateCategory() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      id,
      input,
    }: {
      id: string;
      input: Partial<CategoryInput>;
    }) => {
      const res = await api.patch<Category>(`/categories/${id}`, input);
      return res.data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: categoryKeys.all }),
  });
}

export function useDeleteCategory() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      await api.delete(`/categories/${id}`);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: categoryKeys.all }),
  });
}
