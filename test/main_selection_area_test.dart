import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// SelectionArea / SelectableRegion exige un Overlay ANCESTRO.
// - En `builder` de MaterialApp queda por encima del Navigator/Overlay -> falla.
// - Dentro del body de un Scaffold (bajo Overlay del route) -> OK.
void main() {
  testWidgets('SelectionArea en builder NO tiene Overlay (reproduce el bug)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: Text('hola')),
        builder: (context, child) => SelectionArea(child: child!),
      ),
    );
    final error = tester.takeException();
    expect(error, isNotNull);
    expect(error.toString(), contains('Overlay'));
  });

  testWidgets('SelectionArea dentro del Scaffold SÍ tiene Overlay (fix)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SelectionArea(child: Text('hola')),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('hola'), findsOneWidget);
  });
}
