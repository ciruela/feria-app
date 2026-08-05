import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/dni_ocr_service.dart';
import '../../theme/app_theme.dart';

typedef DniScanAction = void Function(DniScanSide side, ImageSource source);
typedef DniScanBothAction = void Function(ImageSource source);

Future<void> showDniScanSheet(
  BuildContext context, {
  required DniScanAction onScanSide,
  required DniScanBothAction onScanBoth,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final useDialog = width >= 960;

  if (useDialog) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radius),
          side: const BorderSide(color: AppColors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: _DniScanContent(
            onScanSide: onScanSide,
            onScanBoth: onScanBoth,
            onClose: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDecorations.radiusSheet),
      ),
    ),
    builder: (context) => SafeArea(
      child: _DniScanContent(
        onScanSide: onScanSide,
        onScanBoth: onScanBoth,
        onClose: () => Navigator.pop(context),
      ),
    ),
  );
}

class _DniScanContent extends StatelessWidget {
  const _DniScanContent({
    required this.onScanSide,
    required this.onScanBoth,
    required this.onClose,
  });

  final DniScanAction onScanSide;
  final DniScanBothAction onScanBoth;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Escanear DNI', style: AppText.heading.copyWith(fontSize: 22)),
          const SizedBox(height: 6),
          const Text(
            'El frente trae nombre y número; el dorso, domicilio y localidad.',
            style: AppText.bodySmall,
          ),
          const SizedBox(height: 16),
          _DniScanOption(
            code: 'FR',
            title: 'Frente del DNI',
            subtitle: 'Nombre, apellido y número de documento',
            onTap: () {
              onClose();
              onScanSide(DniScanSide.front, ImageSource.camera);
            },
          ),
          const SizedBox(height: 8),
          _DniScanOption(
            code: 'DO',
            title: 'Dorso del DNI',
            subtitle: 'Domicilio y localidad',
            onTap: () {
              onClose();
              onScanSide(DniScanSide.back, ImageSource.camera);
            },
          ),
          const SizedBox(height: 8),
          _DniScanOption(
            code: 'FD',
            title: 'Frente y dorso (cámara)',
            subtitle: 'Escaneo completo en dos pasos',
            onTap: () {
              onClose();
              onScanBoth(ImageSource.camera);
            },
          ),
          const SizedBox(height: 8),
          _DniScanOption(
            code: 'GA',
            title: 'Elegir foto de galería',
            subtitle: 'Una cara del DNI (frente o dorso)',
            onTap: () {
              onClose();
              onScanSide(DniScanSide.unknown, ImageSource.gallery);
            },
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onClose,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppDecorations.buttonPrimary),
              side: const BorderSide(color: AppColors.border),
            ),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

class _DniScanOption extends StatelessWidget {
  const _DniScanOption({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String code;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceTouch,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radius),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppDecorations.radius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  code,
                  style: AppText.label.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                    Text(subtitle, style: AppText.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
