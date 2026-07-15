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
import { Textarea } from "@/components/ui/textarea";
import { Separator } from "@/components/ui/separator";
import { ProductImagesManager } from "./product-images-manager";
import { useCategoryOptions } from "@/lib/categories";
import { useCreateProduct, useUpdateProduct } from "@/lib/products";
import { apiErrorMessage } from "@/lib/api";
import type { Product, ProductInput } from "@/lib/api-types";

// Inputs stay strings so the form's value type matches its defaults exactly
// (no zod transform); numbers are parsed in onSubmit before hitting the API.
const isNonNegativeNumber = (v: string) =>
  v.trim() !== "" && !Number.isNaN(Number(v)) && Number(v) >= 0;

const schema = z.object({
  name: z.string().min(2, "Name is too short").max(160),
  slug: z.string().max(160).optional(),
  description: z.string().min(1, "Description is required"),
  price: z.string().refine(isNonNegativeNumber, "Enter a valid price"),
  compareAtPrice: z
    .string()
    .optional()
    .refine((v) => !v || isNonNegativeNumber(v), "Enter a valid amount"),
  currency: z.string().length(3, "3-letter code"),
  stock: z
    .string()
    .refine(
      (v) => Number.isInteger(Number(v)) && Number(v) >= 0,
      "Enter a valid stock",
    ),
  categoryId: z.string().min(1, "Select a category"),
  isActive: z.boolean(),
});

type FormValues = z.infer<typeof schema>;

const emptyDefaults: FormValues = {
  name: "",
  slug: "",
  description: "",
  price: "",
  compareAtPrice: "",
  currency: "TRY",
  stock: "0",
  categoryId: "",
  isActive: true,
};

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  product: Product | null;
}

export function ProductFormDialog({ open, onOpenChange, product }: Props) {
  const isEdit = Boolean(product);
  const { data: categories } = useCategoryOptions();
  const createMutation = useCreateProduct();
  const updateMutation = useUpdateProduct();

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: emptyDefaults,
  });

  // Re-seed the form whenever the dialog opens for a different product.
  useEffect(() => {
    if (!open) return;
    if (product) {
      reset({
        name: product.name,
        slug: product.slug,
        description: product.description,
        price: product.price,
        compareAtPrice: product.compareAtPrice ?? "",
        currency: product.currency,
        stock: String(product.stock),
        categoryId: product.categoryId,
        isActive: product.isActive,
      });
    } else {
      reset(emptyDefaults);
    }
  }, [open, product, reset]);

  const onSubmit = handleSubmit(async (values) => {
    const input: ProductInput = {
      name: values.name,
      description: values.description,
      price: Number(values.price),
      currency: values.currency.toUpperCase(),
      stock: Number(values.stock),
      categoryId: values.categoryId,
      isActive: values.isActive,
      ...(values.slug ? { slug: values.slug } : {}),
      ...(values.compareAtPrice
        ? { compareAtPrice: Number(values.compareAtPrice) }
        : {}),
    };

    try {
      if (product) {
        await updateMutation.mutateAsync({ id: product.id, input });
        toast.success("Product updated");
      } else {
        await createMutation.mutateAsync(input);
        toast.success("Product created");
      }
      onOpenChange(false);
    } catch (error) {
      toast.error(apiErrorMessage(error, "Could not save product"));
    }
  });

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90dvh] overflow-y-auto sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{isEdit ? "Edit product" : "New product"}</DialogTitle>
          <DialogDescription>
            {isEdit
              ? "Update the product details below."
              : "Add a new product to your catalog."}
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
            <Label htmlFor="description">Description</Label>
            <Textarea id="description" rows={3} {...register("description")} />
            {errors.description && (
              <p className="text-sm text-destructive">
                {errors.description.message}
              </p>
            )}
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="price">Price</Label>
              <Input id="price" type="number" step="0.01" {...register("price")} />
              {errors.price && (
                <p className="text-sm text-destructive">{errors.price.message}</p>
              )}
            </div>
            <div className="space-y-2">
              <Label htmlFor="compareAtPrice">Compare-at (optional)</Label>
              <Input
                id="compareAtPrice"
                type="number"
                step="0.01"
                {...register("compareAtPrice")}
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="stock">Stock</Label>
              <Input id="stock" type="number" {...register("stock")} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="currency">Currency</Label>
              <Input id="currency" maxLength={3} {...register("currency")} />
              {errors.currency && (
                <p className="text-sm text-destructive">
                  {errors.currency.message}
                </p>
              )}
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="categoryId">Category</Label>
            <select
              id="categoryId"
              className="flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-xs outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
              {...register("categoryId")}
            >
              <option value="">Select a category…</option>
              {categories?.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.label}
                </option>
              ))}
            </select>
            {errors.categoryId && (
              <p className="text-sm text-destructive">
                {errors.categoryId.message}
              </p>
            )}
          </div>

          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              className="size-4 rounded border-input"
              {...register("isActive")}
            />
            Active (visible in the store)
          </label>

          <Separator />

          {isEdit && product ? (
            <ProductImagesManager key={product.id} product={product} />
          ) : (
            <p className="text-xs text-muted-foreground">
              Save the product first, then reopen it to upload images.
            </p>
          )}

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
              {isEdit ? "Save changes" : "Create product"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
