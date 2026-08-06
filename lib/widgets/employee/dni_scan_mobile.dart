import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/dni_ocr_service.dart';
import '../../theme/app_theme.dart';

class DniScanOptionData {
  const DniScanOptionData({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.source,
    this.side,
    this.both = false,
  });

  final String code;
  final String title;
  final String subtitle;
  final ImageSource source;
  final DniScanSide? side;
  final bool both;
}

/// Mock 08_Mob — contenido del sheet de escaneo DNI.
class DniScanMobileContent extends StatelessWidget {
  const DniScanMobileContent({
    super.key,
    required this.onScanSide,
    required this.onScanBoth,
    required this.onClose,
  });

  final void Function(DniScanSide side, ImageSource source) onScanSide;
  final void Function(ImageSource source) onScanBoth;
  final VoidCallback onClose;

  static const _options = [
    DniScanOptionData(
      code: 'FR',
      title: 'Frente del DNI',
      subtitle: 'Nombre, apellido y número de documento',
      side: DniScanSide.front,
      source: ImageSource.camera,
    ),
    DniScanOptionData(
      code: 'DO',
      title: 'Dorso del DNI',
      subtitle: 'Domicilio y localidad',
      side: DniScanSide.back,
      source: ImageSource.camera,
    ),
    DniScanOptionData(
      code: 'FD',
      title: 'Frente y dorso (cámara)',
      subtitle: 'Escaneo completo en dos pasos',
      both: true,
      source: ImageSource.camera,
    ),
    DniScanOptionData(
      code: 'GA',
      title: 'Elegir foto de galería',
      subtitle: 'Una cara del DNI (frente o dorso)',
      side: DniScanSide.unknown,
      source: ImageSource.gallery,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Escanear DNI',
            style: AppText.heading.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'El frente trae nombre y número; el dorso, domicilio y localidad.',
            style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppDecorations.radius),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < _options.length; i++) ...[
                  if (i > 0) const Divider(color: AppColors.border, height: 1),
                  DniScanMobileOption(
                    data: _options[i],
                    onTap: () {
                      onClose();
                      final option = _options[i];
                      if (option.both) {
                        onScanBoth(option.source);
                      } else {
                        onScanSide(option.side!, option.source);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onClose,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.surfaceTouch,
                foregroundColor: AppColors.textPrimary,
                minimumSize: const Size.fromHeight(AppDecorations.buttonPrimary),
              ),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }
}

class DniScanMobileOption extends StatelessWidget {
  const DniScanMobileOption({
    super.key,
    required this.data,
    required this.onTap,
  });

  final DniScanOptionData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppDecorations.radius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  data.code,
                  style: AppText.label.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.subtitle,
                      style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                    ),
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
