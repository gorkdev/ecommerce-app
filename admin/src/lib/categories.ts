import { useQuery } from "@tanstack/react-query";
import { api } from "./api";
import type { CategoryNode } from "./api-types";

export interface CategoryOption {
  id: string;
  label: string;
}

// The public /categories endpoint returns a forest; flatten it into indented
// options ("Parent › Child") for a <select>.
function flatten(nodes: CategoryNode[], depth = 0): CategoryOption[] {
  return nodes.flatMap((node) => [
    { id: node.id, label: `${"  ".repeat(depth)}${node.name}` },
    ...flatten(node.children ?? [], depth + 1),
  ]);
}

export function useCategoryOptions() {
  return useQuery({
    queryKey: ["categories", "options"],
    queryFn: async () => {
      const res = await api.get<CategoryNode[]>("/categories");
      return flatten(res.data);
    },
  });
}
