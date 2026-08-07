import 'package:app_feria/widgets/employee/employee_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AR-45: employee sidebar only has Catálogo and Salir', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmployeeSidebar(
            selected: EmployeeNavItem.catalog,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Catálogo'), findsOneWidget);
    expect(find.text('Salir'), findsOneWidget);
    expect(find.text('Por código'), findsNothing);
    expect(find.text('ADMINISTRACIÓN'), findsNothing);
    expect(find.text('OPERACIÓN'), findsNothing);
    expect(find.text('Productos'), findsNothing);
    expect(find.text('Tipo de cambio'), findsNothing);
  });
}
