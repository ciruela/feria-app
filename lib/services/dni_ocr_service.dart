import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

enum DniScanSide { front, back, unknown }

class DniScanResult {
  const DniScanResult({
    this.fullName,
    this.dni,
    this.address,
    this.city,
    this.rawText = '',
    this.side = DniScanSide.unknown,
  });

  final String? fullName;
  final String? dni;
  final String? address;
  final String? city;
  final String rawText;
  final DniScanSide side;

  bool get hasData => hasIdentity || hasAddress;

  bool get hasIdentity =>
      (fullName?.isNotEmpty ?? false) || (dni?.isNotEmpty ?? false);

  bool get hasAddress =>
      (address?.isNotEmpty ?? false) || (city?.isNotEmpty ?? false);

  DniScanResult merge(DniScanResult other) {
    DniScanResult? front;
    DniScanResult? back;

    for (final result in [this, other]) {
      switch (result.side) {
        case DniScanSide.front:
          front = result;
        case DniScanSide.back:
          back = result;
        case DniScanSide.unknown:
          if (result.hasIdentity && front == null) front = result;
          if (result.hasAddress && back == null) back = result;
      }
    }

    front ??= hasIdentity ? this : (other.hasIdentity ? other : null);
    back ??= hasAddress ? this : (other.hasAddress ? other : null);

    return DniScanResult(
      fullName: front?.fullName ?? fullName ?? other.fullName,
      dni: front?.dni ?? dni ?? other.dni,
      address: back?.address ?? address ?? other.address,
      city: back?.city ?? city ?? other.city,
      side: DniScanSide.unknown,
      rawText: rawText.isEmpty
          ? other.rawText
          : other.rawText.isEmpty
              ? rawText
              : '$rawText\n---\n${other.rawText}',
    );
  }
}

class DniOcrService {
  static const _labelTokens = {
    'APELLIDO',
    'SURNAME',
    'NOMBRE',
    'NAME',
    'DOMICILIO',
    'ADDRESS',
    'DIRECCION',
    'DIRECCIÓN',
    'DOCUMENTO',
    'DOCUMENT',
    'SEXO',
    'SEX',
    'NACIONALIDAD',
    'NATIONALITY',
    'FECHA',
    'DATE',
    'NACIMIENTO',
    'BIRTH',
    'TRAMITE',
    'EJEMPLAR',
    'FIRMA',
    'SIGNATURE',
    'IDENTIDAD',
    'IDENTITY',
    'MERCOSUR',
    'REGISTRO',
    'NACIONAL',
    'NATIONAL',
    'EMISION',
    'ISSUE',
    'VENCIMIENTO',
    'EXPIRY',
    'CUIL',
    'CUIT',
  };

  final _picker = ImagePicker();

  Future<DniScanResult?> pickAndScan({
    required ImageSource source,
    DniScanSide hint = DniScanSide.unknown,
  }) async {
    if (kIsWeb) return null;

    final photo = await _picker.pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 95,
      maxWidth: 2400,
    );
    if (photo == null) return null;

    return scanFile(File(photo.path), hint: hint);
  }

  Future<DniScanResult?> pickAndScanBothSides({
    required ImageSource source,
    void Function(String message)? onStep,
  }) async {
    onStep?.call('Paso 1/2: sacá foto al FRENTE (nombre, apellido y DNI)');

    final front = await pickAndScan(source: source, hint: DniScanSide.front);
    if (front == null) return null;

    onStep?.call('Paso 2/2: ahora el DORSO (domicilio y localidad)');

    final back = await pickAndScan(source: source, hint: DniScanSide.back);
    if (back == null) {
      return front.hasData ? front : null;
    }

    return front.merge(back);
  }

  Future<DniScanResult?> scanFile(
    File file, {
    DniScanSide hint = DniScanSide.unknown,
  }) async {
    if (kIsWeb) return null;

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(file.path);
      final recognized = await recognizer.processImage(input);
      return _parse(recognized.text, hint: hint);
    } finally {
      await recognizer.close();
    }
  }

  DniScanResult _parse(String raw, {DniScanSide hint = DniScanSide.unknown}) {
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final upper = raw.toUpperCase();

    final side = hint != DniScanSide.unknown ? hint : _detectSide(upper);

    final dni = _extractDni(raw);
    final fullName = side == DniScanSide.back ? null : _extractName(lines);
    final addressInfo = side == DniScanSide.front
        ? (null, null)
        : _extractAddress(lines, aggressive: side == DniScanSide.back);

    if (side == DniScanSide.front) {
      return DniScanResult(
        fullName: fullName,
        dni: dni,
        rawText: raw,
        side: DniScanSide.front,
      );
    }

    if (side == DniScanSide.back) {
      return DniScanResult(
        address: addressInfo.$1,
        city: addressInfo.$2,
        rawText: raw,
        side: DniScanSide.back,
      );
    }

    return DniScanResult(
      fullName: fullName,
      dni: dni,
      address: addressInfo.$1,
      city: addressInfo.$2,
      rawText: raw,
      side: side,
    );
  }

  DniScanSide _detectSide(String upper) {
    final hasFront = _containsLabel(upper, 'APELLIDO') ||
        _containsLabel(upper, 'SURNAME') ||
        upper.contains('NOMBRE /') ||
        upper.contains('NAME /') ||
        (upper.contains('DOCUMENTO') && upper.contains('N°'));
    final hasBack = _containsLabel(upper, 'DOMICILIO') ||
        _containsLabel(upper, 'ADDRESS') ||
        _containsLabel(upper, 'DIRECCION');

    if (hasBack && !hasFront) return DniScanSide.back;
    if (hasFront && !hasBack) return DniScanSide.front;
    if (hasBack && hasFront) {
      final domicilioIndex = upper.indexOf('DOMICILIO');
      final apellidoIndex = upper.indexOf('APELLIDO');
      if (domicilioIndex >= 0 &&
          apellidoIndex >= 0 &&
          domicilioIndex < apellidoIndex) {
        return DniScanSide.back;
      }
      return DniScanSide.front;
    }
    return DniScanSide.unknown;
  }

  String? _extractDni(String raw) {
    final labeled = RegExp(
      r'(?:DOCUMENTO|DNI|DOC\.?)\s*(?:N[°º.]?\s*)?(\d{1,2}\.?\d{3}\.?\d{3})',
      caseSensitive: false,
    ).firstMatch(raw);
    if (labeled != null) {
      return labeled.group(1)!.replaceAll('.', '');
    }

    final dotted = RegExp(r'\b(\d{1,2}\.\d{3}\.\d{3})\b').firstMatch(raw);
    if (dotted != null) {
      return dotted.group(1)!.replaceAll('.', '');
    }

    final plain = RegExp(r'\b(\d{7,8})\b').allMatches(raw);
    for (final match in plain) {
      final value = match.group(1)!;
      if (value.length >= 7) return value;
    }
    return null;
  }

  String? _extractName(List<String> lines) {
    String? surname;
    String? given;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_isFieldLabel(line, 'APELLIDO') || _isFieldLabel(line, 'SURNAME')) {
        surname = _readValueAfterLabel(lines, i);
      } else if (_isFieldLabel(line, 'NOMBRE') || _isFieldLabel(line, 'NAME')) {
        given = _readValueAfterLabel(lines, i);
      }
    }

    final fromLabels = [given, surname]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(' ');
    if (fromLabels.isNotEmpty) return _titleCase(fromLabels);

    for (final line in lines) {
      if (RegExp(r"^[A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ\s,'-]{8,}$").hasMatch(line) &&
          !_isBoilerplate(line) &&
          !_looksLikeLabel(line) &&
          !_isNoiseLine(line)) {
        return _titleCase(_cleanNameLine(line));
      }
    }

    return null;
  }

  String _readValueAfterLabel(List<String> lines, int labelIndex) {
    final labelLine = lines[labelIndex];
    if (_isBilingualLabelOnly(labelLine)) {
      return _readNextMeaningfulLine(lines, labelIndex + 1, forName: true);
    }

    final sameLine = _valueOnSameLine(labelLine);
    if (sameLine.isNotEmpty) {
      return _cleanNameLine(sameLine);
    }

    return _readNextMeaningfulLine(lines, labelIndex + 1, forName: true);
  }

  String _readNextMeaningfulLine(
    List<String> lines,
    int start, {
    bool forName = false,
  }) {
    for (var i = start; i < lines.length && i < start + 4; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      if (_isBilingualLabelOnly(line) || _looksLikeLabel(line)) continue;
      if (_isBoilerplate(line)) continue;
      if (_isNoiseLine(line)) continue;
      if (forName && _looksLikePersonName(line)) {
        return _cleanNameLine(line);
      }
      if (!forName && _looksLikeAddressLine(line)) {
        return line.trim();
      }
    }
    return '';
  }

  String _valueOnSameLine(String line) {
    if (_isBilingualLabelOnly(line)) return '';

    final parts = line.split(RegExp(r'[:/|]'));
    if (parts.length < 2) return '';

    final tail = parts.sublist(1).join(' ').trim();
    if (tail.isEmpty || _looksLikeLabel(tail) || _isBilingualLabelOnly(tail)) {
      return '';
    }
    return tail;
  }

  bool _isFieldLabel(String line, String label) {
    if (line.length >= 48) return false;
    return _containsLabel(line.toUpperCase(), label);
  }

  bool _containsLabel(String upper, String label) {
    return RegExp('\\b$label\\b').hasMatch(upper);
  }

  bool _isBilingualLabelOnly(String line) {
    final tokens = line
        .toUpperCase()
        .split(RegExp(r'[/|:]+'))
        .expand((part) => part.split(RegExp(r'\s+')))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);

    final words = tokens.toList();
    if (words.isEmpty) return false;

    return words.every(_labelTokens.contains);
  }

  bool _looksLikeLabel(String line) {
    final upper = line.toUpperCase();
    for (final token in _labelTokens) {
      if (_containsLabel(upper, token)) return true;
    }
    return false;
  }

  bool _isBoilerplate(String line) {
    final upper = line.toUpperCase();
    return upper.contains('REPUBLICA') ||
        upper.contains('IDENTIDAD') ||
        upper.contains('MERCOSUR') ||
        upper.contains('REGISTRO NACIONAL');
  }

  bool _isNoiseLine(String line) {
    final upper = line.toUpperCase();
    if (upper.startsWith('IDARG')) return true;
    if (RegExp(r'^[\d\s\-<>]{10,}$').hasMatch(line)) return true;
    if (RegExp(r'^[0-9OIL]{20,}$').hasMatch(line.replaceAll(' ', ''))) {
      return true;
    }
    return false;
  }

  bool _looksLikePersonName(String line) {
    final cleaned = _cleanNameLine(line);
    if (cleaned.length < 3) return false;
    if (RegExp(r'\d').hasMatch(cleaned)) return false;
    return RegExp(r"^[A-Za-zÁÉÍÓÚÑ][A-Za-zÁÉÍÓÚÑ\s,'-]+$").hasMatch(cleaned);
  }

  bool _looksLikeAddressLine(String line) {
    if (_isNoiseLine(line)) return false;
    if (_looksLikeLabel(line)) return false;

    return RegExp(
      r'\b(CALLE|AV\.?|AVENIDA|PASAJE|BV\.?|BO\.?|B°|BARRIO|\d{1,5})\b',
      caseSensitive: false,
    ).hasMatch(line);
  }

  (String?, String?) _extractAddress(
    List<String> lines, {
    bool aggressive = false,
  }) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_isFieldLabel(line, 'DOMICILIO') ||
          _isFieldLabel(line, 'ADDRESS') ||
          _isFieldLabel(line, 'DIRECCION')) {
        var address = _readAddressAfterLabel(lines, i);
        var city = '';

        final start = address.isEmpty ? i + 1 : i + 2;
        for (var j = start; j < lines.length && j < start + 3; j++) {
          final candidate = lines[j].trim();
          if (candidate.isEmpty) continue;
          if (_looksLikeLabel(candidate) || _isNoiseLine(candidate)) continue;

          if (address.isEmpty && _looksLikeAddressLine(candidate)) {
            address = candidate;
            continue;
          }

          if (city.isEmpty && _looksLikeCityLine(candidate)) {
            city = candidate;
            break;
          }
        }

        final parsed = _splitAddressAndCity(address, city);
        if (parsed.$1 != null) return parsed;
      }
    }

    for (final line in lines) {
      if (_looksLikeAddressLine(line)) {
        return _splitAddressAndCity(line.trim(), null);
      }
    }

    if (aggressive) {
      return _extractAddressFallback(lines);
    }

    return (null, null);
  }

  String _readAddressAfterLabel(List<String> lines, int labelIndex) {
    final labelLine = lines[labelIndex];
    if (_isBilingualLabelOnly(labelLine)) {
      return _readNextMeaningfulLine(lines, labelIndex + 1);
    }

    final sameLine = _valueOnSameLine(labelLine);
    if (sameLine.isNotEmpty) return sameLine;

    return _readNextMeaningfulLine(lines, labelIndex + 1);
  }

  (String?, String?) _extractAddressFallback(List<String> lines) {
    final candidates = <String>[];

    for (final line in lines) {
      if (_isNoiseLine(line)) continue;
      if (_isBilingualLabelOnly(line)) continue;
      if (_looksLikeLabel(line)) continue;
      if (_isBoilerplate(line)) continue;
      if (_looksLikePersonName(line) && !line.contains(RegExp(r'\d'))) continue;

      if (_looksLikeAddressLine(line) || _looksLikeCityLine(line)) {
        candidates.add(line.trim());
      }
    }

    if (candidates.isEmpty) return (null, null);
    if (candidates.length == 1) {
      return _splitAddressAndCity(candidates.first, null);
    }

    final street = candidates.firstWhere(
      (line) => _looksLikeAddressLine(line),
      orElse: () => candidates.first,
    );
    final city = candidates
        .where((line) => line != street)
        .firstWhere(
          (line) => _looksLikeCityLine(line),
          orElse: () => candidates.length > 1 ? candidates[1] : '',
        );

    return _splitAddressAndCity(
      street,
      city.isEmpty ? null : city,
    );
  }

  bool _looksLikeCityLine(String line) {
    if (_isNoiseLine(line)) return false;
    return RegExp(r'\b\d{4}\b').hasMatch(line) ||
        RegExp(
          r'\b(CABA|CAP\.?\s*FED|CAPITAL|BUENOS AIRES|PROV\.?|PROVINCIA)\b',
          caseSensitive: false,
        ).hasMatch(line);
  }

  (String?, String?) _splitAddressAndCity(String address, String? city) {
    final normalizedAddress = address.trim();
    if (normalizedAddress.isEmpty) {
      return (null, city?.trim().isEmpty ?? true ? null : city?.trim());
    }

    if (normalizedAddress.contains(',')) {
      final parts =
          normalizedAddress.split(',').map((part) => part.trim()).toList();
      final street = parts.first;
      final locality = parts.sublist(1).join(', ').trim();
      return (
        street.isEmpty ? null : street,
        locality.isNotEmpty ? locality : (city?.isEmpty ?? true ? null : city),
      );
    }

    final cpMatch = RegExp(r'^(.+?)\s+(\d{4}(?:\s*[-–]\s*.+)?)$')
        .firstMatch(normalizedAddress);
    if (cpMatch != null) {
      return (
        cpMatch.group(1)?.trim(),
        cpMatch.group(2)?.trim(),
      );
    }

    return (
      normalizedAddress,
      city == null || city.isEmpty ? null : city.trim(),
    );
  }

  String _cleanNameLine(String value) {
    return value
        .replaceAll(RegExp(r"[^A-Za-zÁÉÍÓÚÑáéíóúñ\s,'-]"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _titleCase(String value) {
    return value
        .toLowerCase()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) => part.length == 1
              ? part.toUpperCase()
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
}
