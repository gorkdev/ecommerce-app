"use client";

import { useEffect, useState } from "react";
import { Users, Loader2, Search } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";
import { UsersTable } from "@/components/users/users-table";
import { UserDetailDialog } from "@/components/users/user-detail-dialog";
import { useAdminUsers, ROLES, ROLE_META } from "@/lib/users";
import type { AdminUserListItem, Role } from "@/lib/api-types";

export default function UsersPage() {
  const [searchInput, setSearchInput] = useState("");
  const [search, setSearch] = useState("");
  const [role, setRole] = useState<Role | "ALL">("ALL");
  const [page, setPage] = useState(1);
  const [viewing, setViewing] = useState<AdminUserListItem | null>(null);

  // Debounce the search box so we don't fire a request on every keystroke;
  // a new search always restarts at the first page.
  useEffect(() => {
    const t = setTimeout(() => {
      setSearch(searchInput.trim());
      setPage(1);
    }, 300);
    return () => clearTimeout(t);
  }, [searchInput]);

  // A role filter change restarts at the first page too.
  const selectRole = (next: Role | "ALL") => {
    setRole(next);
    setPage(1);
  };

  const { data, isPending, isError, isFetching } = useAdminUsers({
    search: search || undefined,
    role: role === "ALL" ? undefined : role,
    page,
    limit: 20,
  });

  const users = data?.data ?? [];
  const meta = data?.meta;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Users</h1>
        <p className="text-sm text-muted-foreground">
          Browse accounts and manage roles.
        </p>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="relative w-full sm:w-64">
          <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            placeholder="Search by name or email…"
            className="pl-9"
          />
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <FilterChip
            label="All"
            active={role === "ALL"}
            onClick={() => selectRole("ALL")}
          />
          {ROLES.map((r) => (
            <FilterChip
              key={r}
              label={ROLE_META[r].label}
              active={role === r}
              onClick={() => selectRole(r)}
            />
          ))}
        </div>
        {isFetching && !isPending && (
          <Loader2 className="size-4 animate-spin text-muted-foreground" />
        )}
      </div>

      {isPending ? (
        <div className="space-y-2 rounded-lg border p-4">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-12 w-full" />
          ))}
        </div>
      ) : isError ? (
        <div className="rounded-lg border border-destructive/30 bg-destructive/5 p-8 text-center text-sm text-destructive">
          Failed to load users. Check that the API is running.
        </div>
      ) : users.length === 0 ? (
        <div className="flex flex-col items-center gap-3 rounded-lg border border-dashed p-12 text-center">
          <Users className="size-8 text-muted-foreground" />
          <div>
            <p className="font-medium">No users found</p>
            <p className="text-sm text-muted-foreground">
              {search || role !== "ALL"
                ? "No accounts match these filters."
                : "Registered customers and admins will appear here."}
            </p>
          </div>
        </div>
      ) : (
        <>
          <UsersTable users={users} onView={setViewing} />
          {meta && (
            <div className="flex items-center justify-between text-sm text-muted-foreground">
              <span>
                Page {meta.page} of {meta.totalPages || 1} · {meta.total} total
              </span>
              <div className="flex gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  disabled={page <= 1}
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                >
                  Previous
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  disabled={page >= (meta.totalPages || 1)}
                  onClick={() => setPage((p) => p + 1)}
                >
                  Next
                </Button>
              </div>
            </div>
          )}
        </>
      )}

      <UserDetailDialog
        user={viewing}
        onOpenChange={(open) => !open && setViewing(null)}
      />
    </div>
  );
}

function FilterChip({
  label,
  active,
  onClick,
}: {
  label: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "rounded-full border px-3 py-1 text-sm transition-colors",
        active
          ? "border-primary bg-primary text-primary-foreground"
          : "border-input text-muted-foreground hover:bg-muted",
      )}
    >
      {label}
    </button>
  );
}
