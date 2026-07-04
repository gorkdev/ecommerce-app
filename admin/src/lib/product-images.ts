import { useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "./api";
import type { ProductImage } from "./api-types";

// Mirrors the API's ALLOWED_IMAGE_TYPES (presign-upload.dto.ts).
export const ALLOWED_IMAGE_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
];
export const MAX_IMAGE_BYTES = 5 * 1024 * 1024; // 5 MB

interface PresignResponse {
  key: string;
  uploadUrl: string;
  publicUrl: string;
}

// Orchestrates the API's 3-step upload: presign → PUT the bytes straight to
// MinIO → attach the object to the product. The MinIO PUT goes through a bare
// fetch (not the `api` axios instance) so the auth interceptor doesn't append a
// Bearer header — the presigned URL already carries its own signature, and an
// extra Authorization header would break the signature check.
export function useUploadProductImage() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      productId,
      file,
      sortOrder,
    }: {
      productId: string;
      file: File;
      sortOrder?: number;
    }): Promise<ProductImage> => {
      const { data: presign } = await api.post<PresignResponse>(
        `/products/${productId}/images/presign`,
        { contentType: file.type },
      );

      const put = await fetch(presign.uploadUrl, {
        method: "PUT",
        body: file,
        headers: { "Content-Type": file.type },
      });
      if (!put.ok) {
        throw new Error("Upload to storage failed");
      }

      const { data: image } = await api.post<ProductImage>(
        `/products/${productId}/images`,
        {
          key: presign.key,
          ...(sortOrder !== undefined ? { sortOrder } : {}),
        },
      );
      return image;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["products"] }),
  });
}

export function useDeleteProductImage() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      productId,
      imageId,
    }: {
      productId: string;
      imageId: string;
    }) => {
      await api.delete(`/products/${productId}/images/${imageId}`);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["products"] }),
  });
}
