"use client";

import { useRef, useState } from "react";
import { toast } from "sonner";
import { ImagePlus, Loader2, Star, Trash2 } from "lucide-react";
import { apiErrorMessage } from "@/lib/api";
import {
  ALLOWED_IMAGE_TYPES,
  MAX_IMAGE_BYTES,
  useDeleteProductImage,
  useUploadProductImage,
} from "@/lib/product-images";
import type { Product, ProductImage } from "@/lib/api-types";

interface Props {
  product: Product;
}

export function ProductImagesManager({ product }: Props) {
  // Local mirror so the grid updates instantly; `['products']` is invalidated
  // in the background to keep the table thumbnails in sync. The parent keys
  // this component by product id, so switching products remounts it and the
  // mirror re-initializes.
  const [images, setImages] = useState<ProductImage[]>(product.images);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const uploadMutation = useUploadProductImage();
  const deleteMutation = useDeleteProductImage();

  const onFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = ""; // let the same file be re-picked after a failure
    if (!file) return;

    if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
      toast.error("Only JPEG, PNG, or WebP images are allowed");
      return;
    }
    if (file.size > MAX_IMAGE_BYTES) {
      toast.error("Image must be 5 MB or smaller");
      return;
    }

    try {
      const image = await uploadMutation.mutateAsync({
        productId: product.id,
        file,
        sortOrder: images.length,
      });
      setImages((prev) => [...prev, image]);
      toast.success("Image uploaded");
    } catch (error) {
      toast.error(apiErrorMessage(error, "Could not upload image"));
    }
  };

  const onDelete = async (image: ProductImage) => {
    setDeletingId(image.id);
    try {
      await deleteMutation.mutateAsync({
        productId: product.id,
        imageId: image.id,
      });
      setImages((prev) => prev.filter((i) => i.id !== image.id));
      toast.success("Image removed");
    } catch (error) {
      toast.error(apiErrorMessage(error, "Could not remove image"));
    } finally {
      setDeletingId(null);
    }
  };

  return (
    <div className="space-y-2">
      <div>
        <p className="text-sm font-medium">Images</p>
        <p className="text-xs text-muted-foreground">
          JPEG, PNG or WebP · up to 5 MB. The first image is the cover.
        </p>
      </div>

      <div className="grid grid-cols-3 gap-3 sm:grid-cols-4">
        {images.map((image, index) => (
          <div
            key={image.id}
            className="group relative aspect-square overflow-hidden rounded-md border bg-muted"
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={image.url} alt="" className="size-full object-cover" />
            {index === 0 && (
              <span className="absolute left-1 top-1 flex items-center gap-1 rounded bg-black/60 px-1.5 py-0.5 text-[10px] font-medium text-white">
                <Star className="size-3" />
                Cover
              </span>
            )}
            <button
              type="button"
              onClick={() => onDelete(image)}
              disabled={deletingId === image.id}
              aria-label="Remove image"
              className="absolute right-1 top-1 flex size-6 items-center justify-center rounded bg-black/60 text-white opacity-0 transition-opacity hover:bg-destructive group-hover:opacity-100 disabled:opacity-100"
            >
              {deletingId === image.id ? (
                <Loader2 className="size-3 animate-spin" />
              ) : (
                <Trash2 className="size-3" />
              )}
            </button>
          </div>
        ))}

        <button
          type="button"
          onClick={() => inputRef.current?.click()}
          disabled={uploadMutation.isPending}
          className="flex aspect-square flex-col items-center justify-center gap-1 rounded-md border border-dashed text-muted-foreground transition-colors hover:border-primary hover:text-primary disabled:opacity-60"
        >
          {uploadMutation.isPending ? (
            <Loader2 className="size-5 animate-spin" />
          ) : (
            <ImagePlus className="size-5" />
          )}
          <span className="text-xs">
            {uploadMutation.isPending ? "Uploading…" : "Add"}
          </span>
        </button>
      </div>

      <input
        ref={inputRef}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        className="hidden"
        onChange={onFileChange}
      />
    </div>
  );
}
