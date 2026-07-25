import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/product.dart';
import '../../models/stock_movimiento.dart';
import '../../services/catalog_service.dart';
import '../../services/seller_service.dart';
import '../../services/supabase_stock_movimientos_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/feria_shell.dart';

class AdminStockMovimientosScreen extends StatefulWidget {
  const AdminStockMovimientosScreen({
    super.key,
    this.productId,
    this.title,
  });

  /// Si es null, muestra los movimientos recientes de todos los productos.
  final String? productId;
  final String? title;

  @override
  State<AdminStockMovimientosScreen> createState() =>
      _AdminStockMovimientosScreenState();
}

class _AdminStockMovimientosScreenState
    extends State<AdminStockMovimientosScreen> {
  final _repo = SupabaseStockMovimientosRepository();
  late Future<List<StockMovimiento>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<StockMovimiento>> _load() {
    if (widget.productId != null) {
      return _repo.fetchForProduct(widget.productId!);
    }
    return _repo.fetchRecent();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  String? _sellerName(SellerService sellers, String? vendedorId) {
    if (vendedorId == null || vendedorId.isEmpty) return null;
    for (final seller in sellers.sellers) {
      if (seller.id == vendedorId) return seller.nombre;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? 'Movimientos de stock';

    if (!AppConfig.useSupabase) {
      return FeriaScaffold(
        appBar: FeriaAppBar(title: Text(title)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Los movimientos de stock requieren Supabase configurado.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    final catalog = context.watch<CatalogService>();
    final sellers = context.watch<SellerService>();

    return FeriaScaffold(
      appBar: FeriaAppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<StockMovimiento>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(onRetry: _refresh, error: '${snapshot.error}');
            }

            final movimientos = snapshot.data ?? const [];
            if (movimientos.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Sin movimientos registrados',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: movimientos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final mov = movimientos[index];
                final product = catalog.productById(mov.productoId);
                final sellerName = _sellerName(sellers, mov.vendedorId);

                return _MovimientoTile(
                  mov: mov,
                  product: product,
                  sellerName: sellerName,
                  showProduct: widget.productId == null,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _MovimientoTile extends StatelessWidget {
  const _MovimientoTile({
    required this.mov,
    required this.product,
    required this.sellerName,
    required this.showProduct,
  });

  final StockMovimiento mov;
  final Product? product;
  final String? sellerName;
  final bool showProduct;

  Color get _color {
    switch (mov.motivo) {
      case StockMotivo.venta:
        return AppColors.primary;
      case StockMotivo.carga:
        return AppColors.success;
      case StockMotivo.ajuste:
        return AppColors.goldDark;
      case StockMotivo.anulacion:
        return AppColors.danger;
    }
  }

  String get _unidad {
    if (product?.isMunicion ?? false) {
      final abs = mov.delta.abs();
      return abs == 1 ? 'caja' : 'cajas';
    }
    return 'u.';
  }

  @override
  Widget build(BuildContext context) {
    final deltaStr = '${mov.delta > 0 ? '+' : ''}${mov.delta} $_unidad';
    final productLabel = product == null
        ? mov.productoId
        : product!.isArma
            ? '${product!.marcaUpper} ${product!.modeloDisplay}'
            : '${product!.marcaUpper} ${product!.codigo}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              mov.motivo.label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showProduct) ...[
                  Text(
                    productLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  formatDateTime(mov.createdAt),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (mov.stockAntes != null && mov.stockDespues != null)
                  Text(
                    'Stock: ${mov.stockAntes} → ${mov.stockDespues}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (sellerName != null)
                  Text(
                    'Vendedor: $sellerName',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (mov.nota.isNotEmpty)
                  Text(
                    mov.nota,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            deltaStr,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: mov.isEntrada ? AppColors.success : _color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, required this.error});

  final VoidCallback onRetry;
  final String error;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'No se pudieron cargar los movimientos',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('REINTENTAR'),
          ),
        ),
      ],
    );
  }
}
