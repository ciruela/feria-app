import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import 'product_seller_visual.dart';
import 'added_to_cart_sheet.dart';

/// Abre selector de cantidad, agrega al carrito y ofrece ir al carrito o seguir.
Future<AddedToCartAction?> promptAddToCart(
  BuildContext context,
  Product product,
) async {
  final cart = context.read<CartService>();
  if (!cart.canAddMore(product)) {
    showStockLimitMessage(context, product);
    return null;
  }

  final remaining = cart.remainingStock(product);
  final maxQty = remaining ?? 999;
  if (maxQty <= 0) {
    showStockLimitMessage(context, product);
    return null;
  }

  final quantity = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _AddToCartSheet(
      product: product,
      maxQuantity: maxQty,
    ),
  );

  if (quantity == null || quantity <= 0 || !context.mounted) return null;

  final result = cart.addProductQuantity(product, quantity);
  if (!context.mounted) return null;

  if (result == CartAddResult.missingPrice) {
    showMissingPriceMessage(context);
    return null;
  }
  if (result == CartAddResult.stockLimitReached) {
    showStockLimitMessage(context, product);
    return null;
  }

  final unit = product.cartQuantityUnit;
  final label = product.isMunicion && product.codigo.isNotEmpty
      ? product.codigo
      : (product.isArma ? product.modeloDisplay : product.marca);
  final qtyLabel = quantity == 1 ? '1 $unit' : '$quantity $unit';

  return showAddedToCartSheet(
    context,
    productLabel: '$label · $qtyLabel',
  );
}

class _AddToCartSheet extends StatefulWidget {
  const _AddToCartSheet({
    required this.product,
    required this.maxQuantity,
  });

  final Product product;
  final int maxQuantity;

  @override
  State<_AddToCartSheet> createState() => _AddToCartSheetState();
}

class _AddToCartSheetState extends State<_AddToCartSheet> {
  late int _quantity;

  Product get product => widget.product;

  @override
  void initState() {
    super.initState();
    _quantity = 1;
  }

  @override
  Widget build(BuildContext context) {
    final unit = product.cartQuantityUnit;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Agregar al carrito',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              product.marcaUpper,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            if (product.cartDisplayCode.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                product.cartDisplayCode,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              product.sellerShortTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (product.sellerTagLabels.isNotEmpty) ...[
              const SizedBox(height: 8),
              ProductSellerTags(labels: product.sellerTagLabels),
            ],
            if (product.stock != null) ...[
              const SizedBox(height: 8),
              Text(
                'Disponible: ${widget.maxQuantity} $unit',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _QtyButton(
                  icon: Icons.remove,
                  onTap: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Text(
                        '$_quantity',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        unit,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                _QtyButton(
                  icon: Icons.add,
                  onTap: _quantity < widget.maxQuantity
                      ? () => setState(() => _quantity++)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, _quantity),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: Text(
                _quantity == 1
                    ? 'AGREGAR 1 $unit'
                    : 'AGREGAR $_quantity $unit',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: onTap == null ? 0.35 : 1,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}
