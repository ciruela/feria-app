import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/presupuesto_page_format.dart';

/// Escala una hoja A4 fija para que se vea en pantalla como se imprime.
class PresupuestoA4Preview extends StatelessWidget {
  const PresupuestoA4Preview({
    super.key,
    required this.child,
    this.maxWidth = 820,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          constraints.maxWidth,
          math.min(maxWidth, PresupuestoPageFormat.sheetWidth),
        );
        final scale = width / PresupuestoPageFormat.sheetWidth;
        final height = PresupuestoPageFormat.sheetHeight * scale;

        return SizedBox(
          width: width,
          height: height,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: PresupuestoPageFormat.sheetWidth,
              height: PresupuestoPageFormat.sheetHeight,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
