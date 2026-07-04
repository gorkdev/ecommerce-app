"use client";

import { useState } from "react";
import { Plus, FolderTree } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { CategoriesTable } from "@/components/categories/categories-table";
import { CategoryFormDialog } from "@/components/categories/category-form-dialog";
import { DeleteCategoryDialog } from "@/components/categories/delete-category-dialog";
import { useCategoryTree } from "@/lib/categories";
import type { CategoryNode } from "@/lib/api-types";

export default function CategoriesPage() {
  const { data: tree, isPending, isError } = useCategoryTree();

  const [formOpen, setFormOpen] = useState(false);
  const [editing, setEditing] = useState<CategoryNode | null>(null);
  const [deleting, setDeleting] = useState<CategoryNode | null>(null);

  const openCreate = () => {
    setEditing(null);
    setFormOpen(true);
  };
  const openEdit = (category: CategoryNode) => {
    setEditing(category);
    setFormOpen(true);
  };

  const isEmpty = !isPending && !isError && (tree?.length ?? 0) === 0;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Categories</h1>
          <p className="text-sm text-muted-foreground">
            Organize your catalog into a nested category tree.
          </p>
        </div>
        <Button onClick={openCreate}>
          <Plus className="size-4" />
          Add category
        </Button>
      </div>

      {isPending ? (
        <div className="space-y-2 rounded-lg border p-4">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton key={i} className="h-11 w-full" />
          ))}
        </div>
      ) : isError ? (
        <div className="rounded-lg border border-destructive/30 bg-destructive/5 p-8 text-center text-sm text-destructive">
          Failed to load categories. Check that the API is running.
        </div>
      ) : isEmpty ? (
        <div className="flex flex-col items-center gap-3 rounded-lg border border-dashed p-12 text-center">
          <FolderTree className="size-8 text-muted-foreground" />
          <div>
            <p className="font-medium">No categories yet</p>
            <p className="text-sm text-muted-foreground">
              Create your first category to start organizing products.
            </p>
          </div>
          <Button onClick={openCreate} variant="outline">
            <Plus className="size-4" />
            Add category
          </Button>
        </div>
      ) : (
        <CategoriesTable
          tree={tree ?? []}
          onEdit={openEdit}
          onDelete={setDeleting}
        />
      )}

      <CategoryFormDialog
        open={formOpen}
        onOpenChange={setFormOpen}
        category={editing}
      />
      <DeleteCategoryDialog
        category={deleting}
        onOpenChange={(open) => !open && setDeleting(null)}
      />
    </div>
  );
}
