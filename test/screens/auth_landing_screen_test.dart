import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_feria/screens/auth/auth_landing_screen.dart';
import 'package:app_feria/services/tenant_session_service.dart';

void main() {
  testWidgets('Auth landing muestra opciones separadas', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TenantSessionService>(
        create: (_) => TenantSessionService(),
        child: const MaterialApp(home: AuthLandingScreen()),
      ),
    );

    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    expect(find.text('Ya tengo una cuenta'), findsOneWidget);
    expect(find.text('REGISTRAR MI ARMERÍA'), findsOneWidget);
    expect(find.text('Quiero crear una organización nueva'), findsOneWidget);
    expect(find.text('Registrarse'), findsNothing);
    expect(find.text('Ingresar'), findsNothing);
  });
}
