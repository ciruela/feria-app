import 'package:app_feria/services/dni_ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ocr = DniOcrService();

  group('frente DNI', () {
    test('extrae apellido, nombre y número de documento', () {
      const raw = '''
REPUBLICA ARGENTINA - MERCOSUR
REGISTRO NACIONAL DE LAS PERSONAS
DOCUMENTO / DOCUMENT
APELLIDO / SURNAME
GONZALEZ
NOMBRE / NAME
JUAN CARLOS
12.345.678
''';

      final result = ocr.parseRecognizedText(raw, hint: DniScanSide.front);

      expect(result.fullName, 'Juan Carlos Gonzalez');
      expect(result.dni, '12345678');
      expect(result.cuil, isNull);
      expect(result.address, isNull);
    });

    test('frente tarjeta nuevo DNI sin puntos', () {
      const raw = '''
APELLIDO / SURNAME
PEREZ
NOMBRE / NAME
MARIA
23456789
''';

      final result = ocr.parseRecognizedText(raw, hint: DniScanSide.front);

      expect(result.fullName, 'Maria Perez');
      expect(result.dni, '23456789');
    });
  });

  group('dorso DNI', () {
    test('extrae domicilio arriba y CUIL al medio (formato viejo)', () {
      const raw = '''
DOMICILIO / ADDRESS
AV SAN MARTIN 1234, PILAR, BUENOS AIRES
LUGAR DE NACIMIENTO / PLACE OF BIRTH
BUENOS AIRES
CUIL
20-12345678-9
TRAMITE N°
01234567890
''';

      final result = ocr.parseRecognizedText(raw, hint: DniScanSide.back);

      expect(result.address, 'AV SAN MARTIN 1234');
      expect(result.city, contains('PILAR'));
      expect(result.cuil, '20-12345678-9');
      expect(result.dni, isNull);
      expect(result.fullName, isNull);
    });

    test('domicilio en una sola línea con comas', () {
      const raw = '''
DOMICILIO / ADDRESS
CALLE FALSA 500, CABA
CUIL
27-30123456-7
''';

      final result = ocr.parseRecognizedText(raw, hint: DniScanSide.back);

      expect(result.address, 'CALLE FALSA 500');
      expect(result.city, 'CABA');
      expect(result.cuil, '27-30123456-7');
    });

    test('no mete MRZ/trámite/boilerplate en el domicilio', () {
      const raw = '''
DOMICILIO / ADDRESS
CALLE FALSA 500
GONZALEZ<<JUAN<CARLOS<<<<<<<<<<<
REGISTRO NACIONAL DE LAS PERSONAS
CUIL
20-12345678-9
TRAMITE N°
01234567890
IDARG1234567<8<<<<<<<<<<<<<<<<
7503023M2503025ARG<<<<<<<<<<<8
''';

      final result = ocr.parseRecognizedText(raw, hint: DniScanSide.back);

      expect(result.address, 'CALLE FALSA 500');
      expect(result.cuil, '20-12345678-9');
      // El domicilio no debe arrastrar el MRZ ni el trámite.
      expect(result.address, isNot(contains('<')));
      expect(result.address, isNot(contains('GONZALEZ')));
      expect(result.city ?? '', isNot(contains('01234567890')));
      expect(result.city ?? '', isNot(contains('REGISTRO')));
    });

    test('domicilio de dos líneas con localidad de nombre simple', () {
      const raw = '''
DOMICILIO / ADDRESS
CALLE FALSA 500
VILLA MARIA
LUGAR DE NACIMIENTO / PLACE OF BIRTH
CORDOBA
CUIL
20-12345678-9
''';

      final result = ocr.parseRecognizedText(raw, hint: DniScanSide.back);

      expect(result.address, 'CALLE FALSA 500');
      expect(result.city, contains('VILLA MARIA'));
    });

    test('CUIL sin guiones', () {
      const raw = '''
DOMICILIO / ADDRESS
RUTA 8 KM 42, LOMAS DE ZAMORA, BUENOS AIRES
CUIL 23-98765432-1
''';

      final result = ocr.parseRecognizedText(raw, hint: DniScanSide.back);

      expect(result.address, isNotNull);
      expect(result.cuil, '23-98765432-1');
    });
  });

  group('merge frente + dorso', () {
    test('combina identidad del frente con domicilio y CUIL del dorso', () {
      const front = '''
APELLIDO / SURNAME
LOPEZ
NOMBRE / NAME
AGUSTIN
30123456
''';
      const back = '''
DOMICILIO / ADDRESS
MITRE 100, SAN ISIDRO, BUENOS AIRES
CUIL
20-30123456-3
''';

      final merged = ocr
          .parseRecognizedText(front, hint: DniScanSide.front)
          .merge(ocr.parseRecognizedText(back, hint: DniScanSide.back));

      expect(merged.fullName, 'Agustin Lopez');
      expect(merged.dni, '30123456');
      expect(merged.cuil, '20-30123456-3');
      expect(merged.address, 'MITRE 100');
      expect(merged.city, contains('SAN ISIDRO'));
    });
  });
}
