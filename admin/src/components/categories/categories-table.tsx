"use client";

import { CornerDownRight, MoreHorizontal, Pencil, Trash2 } from "lucide-react";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { flattenTree } from "@/lib/categories";
import type { CategoryNode } from "@/lib/api-types";

interface Props {
  tree: CategoryNode[];
  onEdit: (category: CategoryNode) => void;
  onDelete: (category: CategoryNode) => void;
}

export function CategoriesTable({ tree, onEdit, onDelete }: Props) {
  const rows = flattenTree(tree);

  return (
    <div className="overflow-x-auto rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Name</TableHead>
            <TableHead>Slug</TableHead>
            <TableHead className="text-right">Subcategories</TableHead>
            <TableHead className="w-[60px]" />
          </TableRow>
        </TableHeader>
        <TableBody>
          {rows.map(({ node, depth }) => (
            <TableRow key={node.id}>
              <TableCell>
                <div
                  className="flex items-center gap-2 font-medium"
                  style={{ paddingLeft: `${depth * 1.25}rem` }}
                >
                  {depth > 0 && (
                    <CornerDownRight className="size-3.5 text-muted-foreground" />
                  )}
                  {node.name}
                </div>
              </TableCell>
              <TableCell className="text-muted-foreground">
                /{node.slug}
              </TableCell>
              <TableCell className="text-right tabular-nums text-muted-foreground">
                {node.children?.length ?? 0}
              </TableCell>
              <TableCell>
                <DropdownMenu>
                  <DropdownMenuTrigger
                    render={
                      <Button variant="ghost" size="icon">
                        <MoreHorizontal className="size-4" />
                      </Button>
                    }
                  />
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem onClick={() => onEdit(node)}>
                      <Pencil className="size-4" />
                      Edit
                    </DropdownMenuItem>
                    <DropdownMenuItem
                      variant="destructive"
                      onClick={() => onDelete(node)}
                    >
                      <Trash2 className="size-4" />
                      Delete
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
