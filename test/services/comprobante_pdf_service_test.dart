import 'package:app_feria/services/comprobante_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ComprobantePdfService.storagePath', () {
    test('segmenta por tenant/año/mes/día/venta.pdf', () {
      final path = ComprobantePdfService.storagePath(
        saleId: 'venta-123',
        date: DateTime(2026, 8, 5),
        tenantId: 'tenant-abc',
      );
      expect(path, 'tenant-abc/2026/08/05/venta-123.pdf');
    });

    test('mes y día con cero a la izquierda', () {
      final path = ComprobantePdfService.storagePath(
        saleId: 'v',
        date: DateTime(2026, 1, 9),
        tenantId: 't',
      );
      expect(path, 't/2026/01/09/v.pdf');
    });

    test('el primer segmento es el tenant_id (RLS del bucket)', () {
      final path = ComprobantePdfService.storagePath(
        saleId: 'v',
        date: DateTime(2026, 12, 31),
        tenantId: 'tenant-xyz',
      );
      expect(path.split('/').first, 'tenant-xyz');
    });

    test('falla si falta tenant_id', () {
      expect(
        () => ComprobantePdfService.storagePath(
          saleId: 'v',
          date: DateTime(2026, 8, 5),
          tenantId: '  ',
        ),
        throwsStateError,
      );
    });
  });
}
