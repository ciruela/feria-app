import 'package:app_feria/utils/municion_calibre.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isMunicionArmaCorta / isMunicionArmaLarga', () {
    test('calibres de pistola/revólver', () {
      for (final calibre in [
        '.9',
        '9mm',
        '9x19',
        '.45',
        '.45 ACP',
        '.40',
        '.38',
        '.357',
        '.380',
        '.32',
        '.44',
        '.25',
      ]) {
        expect(
          isMunicionArmaCorta(calibre: calibre),
          isTrue,
          reason: calibre,
        );
        expect(
          isMunicionArmaLarga(calibre: calibre),
          isFalse,
          reason: calibre,
        );
      }
    });

    test('calibres de rifle/escopeta/.22', () {
      for (final calibre in [
        '.308',
        '.30',
        '.223',
        '.270',
        '.12',
        '.20',
        '.22',
        '.22 LR',
        '.6.5',
        '.9.3',
        '.458',
        '.450',
        '',
      ]) {
        expect(
          isMunicionArmaLarga(calibre: calibre),
          isTrue,
          reason: calibre,
        );
        expect(
          isMunicionArmaCorta(calibre: calibre),
          isFalse,
          reason: calibre,
        );
      }
    });

    test('detecta 9mm desde descripción si calibre vacío', () {
      expect(
        isMunicionArmaCorta(
          calibre: '',
          descripcion: 'C.9 124G FMJ (50)',
        ),
        isTrue,
      );
    });
  });
}
