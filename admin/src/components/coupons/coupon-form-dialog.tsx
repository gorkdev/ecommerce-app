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
import { useCreateCoupon, useUpdateCoupon } from "@/lib/coupons";
import { apiErrorMessage } from "@/lib/api";
import type { Coupon, CouponInput } from "@/lib/api-types";

// Inputs stay strings (matching the form defaults); numbers/dates are parsed in
// onSubmit. The API re-validates everything, so these checks are just for UX.
const isPositiveNumber = (v: string) =>
  v.trim() !== "" && !Number.isNaN(Number(v)) && Number(v) > 0;

const schema = z
  .object({
    code: z.string().min(3, "At least 3 characters").max(40),
    type: z.enum(["PERCENTAGE", "FIXED"]),
    value: z.string().refine(isPositiveNumber, "Enter a value above zero"),
    minSubtotal: z
      .string()
      .optional()
      .refine(
        (v) => !v || (!Number.isNaN(Number(v)) && Number(v) >= 0),
        "Enter a valid amount",
      ),
    maxUses: z
      .string()
      .optional()
      .refine(
        (v) => !v || (Number.isInteger(Number(v)) && Number(v) >= 1),
        "Enter a whole number ≥ 1",
      ),
    expiresAt: z.string().optional(),
    isActive: z.boolean(),
  })
  .superRefine((val, ctx) => {
    if (val.type === "PERCENTAGE" && Number(val.value) > 100) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["value"],
        message: "A percentage cannot exceed 100",
      });
    }
  });

type FormValues = z.infer<typeof schema>;

const emptyDefaults: FormValues = {
  code: "",
  type: "PERCENTAGE",
  value: "",
  minSubtotal: "",
  maxUses: "",
  expiresAt: "",
  isActive: true,
};

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  coupon: Coupon | null;
}

export function CouponFormDialog({ open, onOpenChange, coupon }: Props) {
  const isEdit = Boolean(coupon);
  const createMutation = useCreateCoupon();
  const updateMutation = useUpdateCoupon();

  const {
    register,
    handleSubmit,
    watch,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: emptyDefaults,
  });

  const type = watch("type");

  useEffect(() => {
    if (!open) return;
    reset(
      coupon
        ? {
            code: coupon.code,
            type: coupon.type,
            value: coupon.value,
            minSubtotal:
              Number(coupon.minSubtotal) > 0 ? coupon.minSubtotal : "",
            maxUses: coupon.maxUses !== null ? String(coupon.maxUses) : "",
            expiresAt: coupon.expiresAt ? coupon.expiresAt.slice(0, 10) : "",
            isActive: coupon.isActive,
          }
        : emptyDefaults,
    );
  }, [open, coupon, reset]);

  const onSubmit = handleSubmit(async (values) => {
    try {
      if (coupon) {
        // Update sends explicit nulls to clear an optional field.
        const input: Partial<CouponInput> = {
          code: values.code,
          type: values.type,
          value: Number(values.value),
          minSubtotal: values.minSubtotal ? Number(values.minSubtotal) : 0,
          maxUses: values.maxUses ? Number(values.maxUses) : null,
          expiresAt: values.expiresAt ? values.expiresAt : null,
          isActive: values.isActive,
        };
        await updateMutation.mutateAsync({ id: coupon.id, input });
        toast.success("Coupon updated");
      } else {
        // Create omits empty optionals so the server defaults apply.
        const input: CouponInput = {
          code: values.code,
          type: values.type,
          value: Number(values.value),
          isActive: values.isActive,
          ...(values.minSubtotal
            ? { minSubtotal: Number(values.minSubtotal) }
            : {}),
          ...(values.maxUses ? { maxUses: Number(values.maxUses) } : {}),
          ...(values.expiresAt ? { expiresAt: values.expiresAt } : {}),
        };
        await createMutation.mutateAsync(input);
        toast.success("Coupon created");
      }
      onOpenChange(false);
    } catch (error) {
      toast.error(apiErrorMessage(error, "Could not save coupon"));
    }
  });

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90dvh] overflow-y-auto sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{isEdit ? "Edit coupon" : "New coupon"}</DialogTitle>
          <DialogDescription>
            {isEdit
              ? "Update the coupon details below."
              : "Create a discount code for the storefront."}
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={onSubmit} className="space-y-4" noValidate>
          <div className="space-y-2">
            <Label htmlFor="code">Code</Label>
            <Input
              id="code"
              placeholder="SUMMER25"
              className="font-mono uppercase"
              {...register("code")}
            />
            {errors.code && (
              <p className="text-sm text-destructive">{errors.code.message}</p>
            )}
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="type">Type</Label>
              <select
                id="type"
                className="flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-xs outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
                {...register("type")}
              >
                <option value="PERCENTAGE">Percentage (%)</option>
                <option value="FIXED">Fixed amount</option>
              </select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="value">
                {type === "PERCENTAGE" ? "Percent off" : "Amount off"}
              </Label>
              <Input
                id="value"
                type="number"
                step="0.01"
                {...register("value")}
              />
              {errors.value && (
                <p className="text-sm text-destructive">
                  {errors.value.message}
                </p>
              )}
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="minSubtotal">Min. subtotal (optional)</Label>
              <Input
                id="minSubtotal"
                type="number"
                step="0.01"
                placeholder="0"
                {...register("minSubtotal")}
              />
              {errors.minSubtotal && (
                <p className="text-sm text-destructive">
                  {errors.minSubtotal.message}
                </p>
              )}
            </div>
            <div className="space-y-2">
              <Label htmlFor="maxUses">Max uses (optional)</Label>
              <Input
                id="maxUses"
                type="number"
                placeholder="Unlimited"
                {...register("maxUses")}
              />
              {errors.maxUses && (
                <p className="text-sm text-destructive">
                  {errors.maxUses.message}
                </p>
              )}
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="expiresAt">Expires (optional)</Label>
            <Input id="expiresAt" type="date" {...register("expiresAt")} />
          </div>

          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              className="size-4 rounded border-input"
              {...register("isActive")}
            />
            Active (usable at checkout)
          </label>

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
              {isEdit ? "Save changes" : "Create coupon"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
