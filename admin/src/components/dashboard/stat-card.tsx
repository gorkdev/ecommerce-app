import { Card, CardContent } from "@/components/ui/card";
import { cn } from "@/lib/utils";

interface StatCardProps {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  value: string;
  hint?: string;
  // Draws attention to a value that needs action (e.g. low stock).
  emphasis?: boolean;
}

export function StatCard({
  icon: Icon,
  label,
  value,
  hint,
  emphasis = false,
}: StatCardProps) {
  return (
    <Card>
      <CardContent className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-sm text-muted-foreground">{label}</p>
          <p
            className={cn(
              "mt-1 text-2xl font-semibold tracking-tight tabular-nums",
              emphasis && "text-amber-600 dark:text-amber-400",
            )}
          >
            {value}
          </p>
          {hint && (
            <p className="mt-1 text-xs text-muted-foreground">{hint}</p>
          )}
        </div>
        <div
          className={cn(
            "flex size-10 shrink-0 items-center justify-center rounded-lg",
            emphasis
              ? "bg-amber-100 text-amber-600 dark:bg-amber-500/15 dark:text-amber-400"
              : "bg-muted text-muted-foreground",
          )}
        >
          <Icon className="size-5" />
        </div>
      </CardContent>
    </Card>
  );
}
