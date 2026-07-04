"use client";

import { useEffect } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  flattenTree,
  subtreeIds,
  useCategoryTree,
  useCreateCategory,
  useUpdateCategory,
} from "@/lib/categories";
import { apiErrorMessage } from "@/lib/api";
import type { CategoryInput, CategoryNode } from "@/lib/api-types";

const schema = z.object({
  name: z.string().min(2, "Name is too short").max(80),
  slug: z.string().max(80).optional(),
  parentId: z.string(), // "" means top level
});

type FormValues = z.infer<typeof schema>;

const emptyDefaults: FormValues = { name: "", slug: "", parentId: "" };

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  category: CategoryNode | null;
}

export function CategoryFormDialog({ open, onOpenChange, category }: Props) {
  const isEdit = Boolean(category);
  const { data: tree } = useCategoryTree();
  const createMutation = useCreateCategory();
  const updateMutation = useUpdateCategory();

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: emptyDefaults,
  });

  useEffect(() => {
    if (!open) return;
    reset(
      category
        ? {
            name: category.name,
            slug: category.slug,
            parentId: category.parentId ?? "",
          }
        : emptyDefaults,
    );
  }, [open, category, reset]);

  // A category may not be parented under itself or any of its descendants.
  const excluded = new Set<string>();
  if (category && tree) {
    const node = flattenTree(tree).find((f) => f.node.id === category.id)?.node;
    if (node) subtreeIds(node).forEach((id) => excluded.add(id));
  }
  const parentOptions = (tree ? flattenTree(tree) : []).filter(
    ({ node }) => !excluded.has(node.id),
  );

  const onSubmit = handleSubmit(async (values) => {
    try {
      if (category) {
        // "" detaches to the top level (parentId: null); the API supports it.
        const input: Partial<CategoryInput> = {
          name: values.name,
          parentId: values.parentId ? values.parentId : null,
          ...(values.slug ? { slug: values.slug } : {}),
        };
        await updateMutation.mutateAsync({ id: category.id, input });
        toast.success("Category updated");
      } else {
        const input: CategoryInput = {
          name: values.name,
          ...(values.slug ? { slug: values.slug } : {}),
          ...(values.parentId ? { parentId: values.parentId } : {}),
        };
        await createMutation.mutateAsync(input);
        toast.success("Category created");
      }
      onOpenChange(false);
    } catch (error) {
      toast.error(apiErrorMessage(error, "Could not save category"));
    }
  });

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{isEdit ? "Edit category" : "New category"}</DialogTitle>
          <DialogDescription>
            {isEdit
              ? "Update the category details below."
              : "Add a category to organize your catalog."}
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={onSubmit} className="space-y-4" noValidate>
          <div className="space-y-2">
            <Label htmlFor="name">Name</Label>
            <Input id="name" {...register("name")} />
            {errors.name && (
              <p className="text-sm text-destructive">{errors.name.message}</p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="slug">Slug (optional)</Label>
            <Input id="slug" placeholder="auto from name" {...register("slug")} />
          </div>

          <div className="space-y-2">
            <Label htmlFor="parentId">Parent category</Label>
            <select
              id="parentId"
              className="flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-xs outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
              {...register("parentId")}
            >
              <option value="">— Top level —</option>
              {parentOptions.map(({ node, depth }) => (
                <option key={node.id} value={node.id}>
                  {`${"  ".repeat(depth)}${node.name}`}
                </option>
              ))}
            </select>
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting && <Loader2 className="size-4 animate-spin" />}
              {isEdit ? "Save changes" : "Create category"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
