import 'package:flutter/material.dart';

import '../../models/presupuesto_document.dart';

class PresupuestoHeader extends StatelessWidget {
  const PresupuestoHeader({
    super.key,
    required this.day,
    required this.month,
    required this.year,
  });

  final String day;
  final String month;
  final String year;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          height: 78,
          child: CustomPaint(
            painter: _LogoPainter(),
            child: const Center(
              child: Text(
                'WORLD\nGUNS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                PresupuestoBranding.companyName,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              Text(
                PresupuestoBranding.businessLine,
                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800),
              ),
              Text(
                PresupuestoBranding.servicesLine,
                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2),
              Text(
                PresupuestoBranding.addressLine,
                style: TextStyle(fontSize: 8.5),
              ),
              Text(
                PresupuestoBranding.phoneLine,
                style: TextStyle(fontSize: 8.5),
              ),
              Text(
                PresupuestoBranding.adminLine,
                style: TextStyle(fontSize: 8.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 118,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                PresupuestoBranding.documentTitle,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const Text(
                PresupuestoBranding.documentSubtitle,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
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
              const SizedBox(height: 6),
              const Text(
                PresupuestoBranding.footerNote,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 6.5, height: 1.25),
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
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, size.width / 2 - 2, paint);
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
