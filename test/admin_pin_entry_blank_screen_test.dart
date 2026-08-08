import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_feria/screens/admin/admin_home_screen.dart';
import 'package:app_feria/services/admin_service.dart';
import 'package:app_feria/services/auth_service.dart';
import 'package:app_feria/services/catalog_service.dart';
import 'package:app_feria/services/seller_service.dart';
import 'package:app_feria/services/tenant_session_service.dart';

/// Proves which committed patterns blank the admin panel after PIN.
///
/// Hypothesis matrix (flutter_test = DEBUG, asserts ON):
/// - SelectionArea in MaterialApp.builder (commit 6d32118) → Overlay error
/// - Nested admin Navigator alone (8bbdce8 / HEAD) → still paints
/// - Both together (committed web pattern) → Overlay error
/// - Removing only SelectionArea → AdminHome paints (nested nav NOT the cause)
///
/// Note: debugCheckHasOverlay is assert-only, so RELEASE/profile builds do not
/// throw this Overlay error. Native mobile never wraps with SelectionArea
/// (kIsWeb). If blank persists in those modes after removing SelectionArea,
/// it is a separate defect — these tests show nested Navigator is insufficient
/// to explain it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrapAdmin(Widget home, {bool selectionAreaInBuilder = false}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CatalogService>.value(value: CatalogService()),
        ChangeNotifierProvider<AuthService>.value(value: AuthService()),
        ChangeNotifierProvider<AdminService>.value(value: AdminService()),
        ChangeNotifierProvider<SellerService>.value(value: SellerService()),
        ChangeNotifierProvider<TenantSessionService>.value(
          value: TenantSessionService(),
        ),
      ],
      child: MaterialApp(
        builder: selectionAreaInBuilder
            ? (context, child) {
                if (child == null) return const SizedBox.shrink();
                return SelectionArea(child: child);
              }
            : null,
        home: home,
      ),
    );
  }

  Widget headAdminNavigator() {
    return Navigator(
      key: GlobalKey<NavigatorState>(),
      onGenerateInitialRoutes: (_, __) {
        return [
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/'),
            builder: (_) => const AdminHomeScreen(),
          ),
        ];
      },
      onGenerateRoute: (settings) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AdminHomeScreen(),
        );
      },
    );
  }

  testWidgets(
    'A) SelectionArea in MaterialApp.builder → No Overlay',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(body: Text('ok')),
          builder: (context, child) => SelectionArea(child: child!),
        ),
      );
      final error = tester.takeException();
      expect(error, isNotNull);
      expect('$error', contains('Overlay'));
    },
  );

  testWidgets(
    'B) Nested admin Navigator WITHOUT SelectionArea paints AdminHome',
    (tester) async {
      await tester.pumpWidget(wrapAdmin(headAdminNavigator()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Panel de administración'), findsOneWidget);
    },
  );

  testWidgets(
    'C) HEAD web combo (SelectionArea builder + nested admin nav) → Overlay',
    (tester) async {
      await tester.pumpWidget(
        wrapAdmin(headAdminNavigator(), selectionAreaInBuilder: true),
      );
      final error = tester.takeException();
      expect(error, isNotNull);
      expect('$error', contains('Overlay'));
    },
  );

  testWidgets(
    'D) Remove SelectionArea only → AdminHome paints (nested nav not the cause)',
    (tester) async {
      await tester.pumpWidget(wrapAdmin(headAdminNavigator()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Panel de administración'), findsOneWidget);
    },
  );

  testWidgets(
    'E) Dirty fix: AdminHome direct (no nested nav) also paints',
    (tester) async {
      await tester.pumpWidget(wrapAdmin(const AdminHomeScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Panel de administración'), findsOneWidget);
    },
  );
}
