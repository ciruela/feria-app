import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_feria/models/admin_user.dart';
import 'package:app_feria/services/admin_service.dart';
import 'package:app_feria/services/auth_service.dart';
import 'package:app_feria/widgets/admin_pin_entry.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AdminPinEntry solo dispara onSubmit una vez al completar PIN',
      (tester) async {
    var submits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminPinEntry(
            onSubmit: (_) => submits++,
          ),
        ),
      ),
    );

    // 4º dígito auto-submit + Enter: antes podía disparar 2 veces y
    // el 2º Navigator.pop se comía AuthGate → pantalla negra.
    await tester.enterText(find.byType(TextField), '2580');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(submits, 1);
  });

  testWidgets('PIN correcto cierra el diálogo una sola vez y deja home vivo',
      (tester) async {
    final auth = AuthService();
    final admins = AdminService();
    await auth.load();
    AdminUser? result;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<AdminService>.value(value: admins),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      result = await showDialog<AdminUser>(
                        context: context,
                        builder: (dialogContext) {
                          var closing = false;
                          return AlertDialog(
                            content: AdminPinEntry(
                              onSubmit: (pin) {
                                if (closing) return;
                                if (!auth.verifyAdminPin(pin)) return;
                                closing = true;
                                Navigator.of(dialogContext).maybePop(
                                  const AdminUser(
                                    id: 'master',
                                    nombre: 'Admin',
                                    pin: '',
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2580');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result?.id, 'master');
    expect(find.text('open'), findsOneWidget);
  });
}
