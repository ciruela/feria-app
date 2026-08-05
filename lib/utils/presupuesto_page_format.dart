import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

/// Medidas A4 compartidas entre vista previa (Flutter) y PDF de impresión.
abstract final class PresupuestoPageFormat {
  static final PdfPageFormat pdf = PdfPageFormat.a4;

  /// Ancho/alto A4 en puntos tipográficos (72 pt ≈ 1 pulgada).
  static const double sheetWidth = 595.28;
  static const double sheetHeight = 841.89;

  static const double marginHorizontal = 28;
  static const double marginVertical = 22;
  static const double borderPadding = 12;

  static const EdgeInsets pageMargins = EdgeInsets.symmetric(
    horizontal: marginHorizontal,
    vertical: marginVertical,
  );

  static const EdgeInsets borderPaddingInsets = EdgeInsets.all(borderPadding);

  static double get aspectRatio => sheetWidth / sheetHeight;

  /// Área útil dentro del borde del comprobante.
  static double get innerWidth =>
      sheetWidth - marginHorizontal * 2 - borderPadding * 2;

  static double get innerHeight =>
      sheetHeight - marginVertical * 2 - borderPadding * 2;
}
