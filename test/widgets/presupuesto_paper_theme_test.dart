import 'package:app_feria/theme/app_theme.dart';
import 'package:app_feria/widgets/presupuesto/presupuesto_paper_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presupuesto paper theme disables dark filled inputs', () {
    final paper = presupuestoPaperTheme(AppTheme.light());

    expect(paper.brightness, Brightness.light);
    expect(paper.inputDecorationTheme.filled, isFalse);
    expect(paper.inputDecorationTheme.fillColor, Colors.transparent);
    expect(paper.colorScheme.surface, Colors.white);
    expect(paper.colorScheme.surfaceContainerHighest, isNot(AppColors.surfaceRaised));
    expect(paper.colorScheme.onSurface, Colors.black);
    expect(paper.textSelectionTheme.cursorColor, Colors.black);
  });

  testWidgets('PresupuestoPaperTheme paints ink on white fields', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PresupuestoPaperTheme(
            child: Builder(
              builder: (context) {
                final decoration = Theme.of(context).inputDecorationTheme;
                expect(decoration.filled, isFalse);
                expect(Theme.of(context).colorScheme.onSurface, Colors.black);
                return const TextField();
              },
            ),
          ),
        ),
      ),
    );
  });
}
