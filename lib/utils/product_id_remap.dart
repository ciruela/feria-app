import '../models/product.dart';

/// AR-35: when upsert restores a soft-deleted row under a different id,
/// rewrite local product lists and stock maps to the persisted id.
void applyProductIdRemaps(
  Map<String, String> remapped, {
  required List<Product> products,
  List<Product>? changedProducts,
  Map<String, int?>? stockTargetById,
  Map<String, int?>? serverStocks,
}) {
  if (remapped.isEmpty) return;
  for (final entry in remapped.entries) {
    final fromId = entry.key;
    final toId = entry.value;

    final productIndex = products.indexWhere((item) => item.id == fromId);
    if (productIndex != -1) {
      products[productIndex] = products[productIndex].copyWith(id: toId);
    }

    if (changedProducts != null) {
      final changedIndex =
          changedProducts.indexWhere((item) => item.id == fromId);
      if (changedIndex != -1) {
        changedProducts[changedIndex] =
            changedProducts[changedIndex].copyWith(id: toId);
      }
    }

    if (stockTargetById != null && stockTargetById.containsKey(fromId)) {
      stockTargetById[toId] = stockTargetById.remove(fromId);
    }
    if (serverStocks != null && serverStocks.containsKey(fromId)) {
      serverStocks[toId] = serverStocks.remove(fromId);
    }
  }
}
