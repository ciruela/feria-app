/// Calibres frecuentes en armerías (Argentina). Se combinan con los del catálogo.
abstract final class CommonCalibers {
  static const values = [
    '9MM',
    '.22 LR',
    '.223 REM',
    '5.56X45',
    '.308 WIN',
    '7.62X39',
    '.38 SPECIAL',
    '.380 ACP',
    '.45 ACP',
    '.357 MAG',
    '.40 S&W',
    '12 GA',
    '20 GA',
    '.30-06',
    '.270 WIN',
    '6.5 CREEDMOOR',
    '.243 WIN',
    '.32 ACP',
    '.25 ACP',
    '10MM AUTO',
    '.17 HMR',
    '.410',
    '7.62X51',
    '.300 WIN MAG',
    '.22-250',
    '.50 BMG',
  ];

  static List<String> mergedWith(Iterable<String> fromCatalog) {
    final seen = <String>{};
    final merged = <String>[];

    void add(String raw) {
      final value = raw.trim();
      if (value.isEmpty) return;
      final key = value.toLowerCase();
      if (seen.add(key)) merged.add(value);
    }

    for (final calibre in values) {
      add(calibre);
    }
    for (final calibre in fromCatalog) {
      add(calibre);
    }

    merged.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return merged;
  }

  /// Atajos visibles debajo del campo (los más usados en mostrador).
  static const quickPick = [
    '9MM',
    '.22 LR',
    '.223 REM',
    '.308 WIN',
    '.38 SPECIAL',
    '.380 ACP',
    '.45 ACP',
    '12 GA',
  ];
}
