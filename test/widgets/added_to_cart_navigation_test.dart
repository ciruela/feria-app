import 'package:app_feria/widgets/added_to_cart_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget cartStub(BuildContext context) {
    return const Scaffold(body: Text('cart-stub'));
  }

  Future<void> pumpStack(
    WidgetTester tester, {
    required List<Widget> pages,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onGenerateInitialRoutes: (_, __) => [
            for (final page in pages)
              MaterialPageRoute<void>(builder: (_) => page),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  NavigatorState navigatorState(WidgetTester tester) {
    return tester.state(find.byType(Navigator).last);
  }

  testWidgets(
    'AR-46: go to cart from catalog root keeps catalog under cart',
    (tester) async {
      await pumpStack(
        tester,
        pages: [
          Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () => handleAddedToCartNavigation(
                    context,
                    AddedToCartAction.goToCart,
                    cartBuilder: cartStub,
                  ),
                  child: const Text('go-cart'),
                ),
              );
            },
          ),
        ],
      );

      await tester.tap(find.text('go-cart'));
      await tester.pumpAndSettle();

      expect(find.text('cart-stub'), findsOneWidget);

      navigatorState(tester).pop();
      await tester.pumpAndSettle();

      expect(find.text('cart-stub'), findsNothing);
      expect(find.text('go-cart'), findsOneWidget);
    },
  );

  testWidgets(
    'AR-46: go to cart from detail pops detail then returns to catalog',
    (tester) async {
      await pumpStack(
        tester,
        pages: [
          const Scaffold(body: Text('catalog')),
          Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () => handleAddedToCartNavigation(
                    context,
                    AddedToCartAction.goToCart,
                    cartBuilder: cartStub,
                  ),
                  child: const Text('go-cart'),
                ),
              );
            },
          ),
        ],
      );

      expect(find.text('catalog'), findsNothing);

      await tester.tap(find.text('go-cart'));
      await tester.pumpAndSettle();

      expect(find.text('cart-stub'), findsOneWidget);
      expect(find.text('go-cart'), findsNothing);

      navigatorState(tester).pop();
      await tester.pumpAndSettle();

      expect(find.text('cart-stub'), findsNothing);
      expect(find.text('catalog'), findsOneWidget);
    },
  );
}
