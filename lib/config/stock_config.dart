/// Umbral compartido para alertas de stock bajo en catálogo y admin.
const int kLowStockThreshold = 3;

bool isLowStock(int? stock) =>
    stock != null && stock > 0 && stock <= kLowStockThreshold;
