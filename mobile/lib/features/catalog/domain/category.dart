/// One node of the category forest served by `GET /categories`.
///
/// The API nests children under their parents, so parsing is recursive.
final class Category {
  const Category({
    required this.id,
    required this.slug,
    required this.name,
    required this.parentId,
    required this.children,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    slug: json['slug'] as String,
    name: json['name'] as String,
    parentId: json['parentId'] as String?,
    children: ((json['children'] as List<dynamic>?) ?? const <dynamic>[])
        .map((child) => Category.fromJson(child as Map<String, dynamic>))
        .toList(),
  );

  final String id;
  final String slug;
  final String name;
  final String? parentId;
  final List<Category> children;

  /// Depth-first flattening of a forest — the filter chips need a flat list,
  /// and a product's `categoryId` may point at any depth of the tree.
  static List<Category> flatten(List<Category> roots) {
    final List<Category> flat = <Category>[];
    void visit(Category node) {
      flat.add(node);
      node.children.forEach(visit);
    }

    roots.forEach(visit);
    return flat;
  }
}
