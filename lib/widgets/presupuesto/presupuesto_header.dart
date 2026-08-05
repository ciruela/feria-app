import 'package:flutter/material.dart';

import '../../models/presupuesto_branding.dart';

class PresupuestoHeader extends StatelessWidget {
  const PresupuestoHeader({
    super.key,
    required this.branding,
    required this.day,
    required this.month,
    required this.year,
    required this.formattedDate,
  });

  final PresupuestoBranding branding;
  final String day;
  final String month;
  final String year;
  final String formattedDate;

  @override
  Widget build(BuildContext context) {
    if (branding.isUrban) {
      return _UrbanHeader(
        branding: branding,
        formattedDate: formattedDate,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (branding.logoText.isNotEmpty) ...[
          SizedBox(
            width: 78,
            height: 78,
            child: CustomPaint(
              painter: _LogoPainter(showCrosshair: branding.isWorldGuns),
              child: Center(
                child: Text(
                  branding.logoText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: branding.isWorldGuns ? 9 : 11,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                branding.companyName,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              if (branding.businessLine.isNotEmpty)
                Text(
                  branding.businessLine,
                  style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800),
                ),
              if (branding.servicesLine.isNotEmpty)
                Text(
                  branding.servicesLine,
                  style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700),
                ),
              if (branding.addressLine.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(branding.addressLine, style: const TextStyle(fontSize: 8.5)),
              ],
              if (branding.phoneLine.isNotEmpty)
                Text(branding.phoneLine, style: const TextStyle(fontSize: 8.5)),
              if (branding.adminLine.isNotEmpty)
                Text(branding.adminLine, style: const TextStyle(fontSize: 8.5)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 118,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                branding.documentTitle,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              Text(
                branding.documentSubtitle,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              if (branding.useSingleDateLine)
                Text(
                  'Fecha: $formattedDate',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DateBox(value: day),
                    const SizedBox(width: 4),
                    _DateBox(value: month),
                    const SizedBox(width: 4),
                    _DateBox(value: year, wide: true),
                  ],
                ),
              if (branding.footerNote.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  branding.footerNote,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 6.5, height: 1.25),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _UrbanHeader extends StatelessWidget {
  const _UrbanHeader({
    required this.branding,
    required this.formattedDate,
  });

  final PresupuestoBranding branding;
  final String formattedDate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                branding.companyName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              Text(
                branding.addressLine,
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700),
              ),
              if (branding.taxLine.isNotEmpty)
                Text(
                  branding.taxLine,
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
                ),
              Text(
                branding.phoneLine,
                style: const TextStyle(fontSize: 9.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 180,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                branding.documentTitle,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              Text(
                branding.documentSubtitle,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Fecha: $formattedDate',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.value, this.wide = false});

  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? 42 : 28,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Text(
        value,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.showCrosshair});

  final bool showCrosshair;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, size.width / 2 - 2, paint);
    if (showCrosshair) {
      canvas.drawLine(
        Offset(center.dx, 4),
        Offset(center.dx, size.height - 4),
        paint,
      );
      canvas.drawLine(
        Offset(4, center.dy),
        Offset(size.width - 4, center.dy),
        paint,
      );
      canvas.drawCircle(center, 6, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) =>
      oldDelegate.showCrosshair != showCrosshair;
}
