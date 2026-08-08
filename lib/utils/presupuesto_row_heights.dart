import 'dart:math' as math;

import '../models/presupuesto_document.dart';

/// Reparte el alto fijo del A4 entre filas de la tabla de presupuesto.
///
/// AR-59: sin esto, filas de arma (campo SERIE) suman más que el cuerpo
/// disponible y ClipRect/PDF cortan la sección debajo del total
/// (checks, firma, saldo).
///
/// Reglas:
/// - Filas reales (arma/normal) conservan su alto preferido si entran, y se
///   estiran (hasta [maxGrow]) para llenar la hoja.
/// - Filas de relleno solo ocupan el sobrante y se achican primero.
/// - Si las filas reales no entran, todo se escala hacia abajo (fit-to-page).
class PresupuestoRowHeights {
  const PresupuestoRowHeights({
    required this.arma,
    required this.normal,
    required this.filler,
  });

  final double arma;
  final double normal;
  final double filler;

  double forRow(PresupuestoItemRow row) => row.isArma ? arma : normal;

  static const maxGrow = 1.6;

  static PresupuestoRowHeights resolve({
    required List<PresupuestoItemRow> rows,
    required double? bodyHeight,
    required double headerHeight,
    required double armaPref,
    required double normalPref,
    required double fillerPref,
  }) {
    if (bodyHeight == null) {
      return PresupuestoRowHeights(
        arma: armaPref,
        normal: normalPref,
        filler: fillerPref,
      );
    }

    final available = bodyHeight - headerHeight;
    if (available <= 0) {
      return const PresupuestoRowHeights(arma: 0, normal: 0, filler: 0);
    }

    var armaCount = 0;
    var normalCount = 0;
    var fillerCount = 0;
    for (final row in rows) {
      if (row.isEmpty) {
        fillerCount++;
      } else if (row.isArma) {
        armaCount++;
      } else {
        normalCount++;
      }
    }

    final realTotal = armaCount * armaPref + normalCount * normalPref;

    if (realTotal >= available) {
      final scale = realTotal <= 0 ? 1.0 : available / realTotal;
      return PresupuestoRowHeights(
        arma: armaPref * scale,
        normal: normalPref * scale,
        filler: 0,
      );
    }

    final filler = fillerCount > 0
        ? math.min(fillerPref, (available - realTotal) / fillerCount)
        : 0.0;
    final realSpace = available - filler * fillerCount;
    final grow = realTotal <= 0
        ? 1.0
        : (realSpace / realTotal).clamp(1.0, maxGrow);

    return PresupuestoRowHeights(
      arma: armaPref * grow,
      normal: normalPref * grow,
      filler: filler,
    );
  }
}
