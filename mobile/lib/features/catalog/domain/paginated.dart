/// The API's standard page envelope: `{data: [...], meta: {...}}`.
final class Paginated<T> {
  const Paginated({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory Paginated.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) parseItem,
  ) {
    final meta = json['meta'] as Map<String, dynamic>;
    return Paginated<T>(
      items: (json['data'] as List<dynamic>)
          .map((item) => parseItem(item as Map<String, dynamic>))
          .toList(),
      page: meta['page'] as int,
      limit: meta['limit'] as int,
      total: meta['total'] as int,
      totalPages: meta['totalPages'] as int,
    );
  }

  final List<T> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;
}
