import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product_prices.dart';
import '../services/cart_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/pricing_service.dart';
import '../services/pricing_settings_service.dart';
import '../services/seller_service.dart';
import '../utils/formatters.dart';
import '../widgets/quick_nav_bar.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  PaymentMethod _paymentMethod = PaymentMethod.lista;
  final _pricing = PricingService();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final exchangeRate = context.watch<ExchangeRateService>();
    final pricingSettings = context.watch<PricingSettingsService>();
    final seller = context.watch<SellerService>().selected;

    var total = 0.0;
    for (final item in cart.items) {
      final prices = _pricing.pricesFor(
        item.product,
        exchangeRate,
        pricingSettings,
      );
      total += _paymentMethod.totalFor(prices) * item.quantity;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrito'),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: cart.clear,
              child: const Text(
                'VACIAR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (seller != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFE8F5EE),
              child: Text(
                'Vendedor: ${seller.nombre}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PaymentMethod.values.map((method) {
                return ChoiceChip(
                  label: Text(method.label),
                  selected: _paymentMethod == method,
                  onSelected: (_) {
                    setState(() => _paymentMethod = method);
                  },
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: cart.isEmpty
                ? const Center(
                    child: Text(
                      'Carrito vacío',
                      style: TextStyle(fontSize: 20),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      final prices = _pricing.pricesFor(
                        item.product,
                        exchangeRate,
                        pricingSettings,
                      );
                      final lineTotal =
                          _paymentMethod.totalFor(prices) * item.quantity;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.marcaUpper,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                item.product.isArma
                                    ? item.product.modeloDisplay
                                    : item.product.codigo,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => cart.changeQuantity(
                                      item.product.id,
                                      item.quantity - 1,
                                    ),
                                    icon: const Icon(Icons.remove_circle),
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => cart.changeQuantity(
                                      item.product.id,
                                      item.quantity + 1,
                                    ),
                                    icon: const Icon(Icons.add_circle),
                                  ),
                                  const Spacer(),
                                  Text(
                                    formatArs(lineTotal),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (!cart.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                children: [
                  Text(
                    'Total (${_paymentMethod.label})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    formatArs(total),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F7A52),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: QuickNavBar(
        cartCount: cart.itemCount,
        onCartTap: () {},
      ),
    );
  }
}
