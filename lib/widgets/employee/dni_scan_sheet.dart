import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/dni_ocr_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/layout_breakpoints.dart';
import 'dni_scan_mobile.dart';

typedef DniScanAction = void Function(DniScanSide side, ImageSource source);
typedef DniScanBothAction = void Function(ImageSource source);

Future<void> showDniScanSheet(
  BuildContext context, {
  required DniScanAction onScanSide,
  required DniScanBothAction onScanBoth,
}) {
  final isDesktop =
      LayoutBreakpoints.isDesktop(MediaQuery.sizeOf(context).width);

  if (isDesktop) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.scrim,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        backgroundColor: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusSheet),
          side: const BorderSide(color: AppColors.border, width: AppDecorations.hairline),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _DniScanDesktopContent(
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
    isScrollControlled: true,
    backgroundColor: AppColors.canvas,
    barrierColor: AppColors.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDecorations.radiusSheet),
      ),
    ),
    builder: (context) => SafeArea(
      child: DniScanMobileContent(
        onScanSide: onScanSide,
        onScanBoth: onScanBoth,
        onClose: () => Navigator.pop(context),
      ),
    ),
  );
}

class _DniScanDesktopContent extends StatelessWidget {
  const _DniScanDesktopContent({
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
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Escanear DNI',
            textAlign: TextAlign.center,
            style: AppText.heading.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'El frente trae nombre y DNI; el dorso, domicilio arriba y CUIL al medio.',
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          _DniScanDesktopOption(
            code: 'FR',
            title: 'Frente del DNI',
            subtitle: 'Nombre, apellido y número de documento',
            onTap: () {
              onClose();
              onScanSide(DniScanSide.front, ImageSource.camera);
            },
          ),
          const SizedBox(height: 6),
          _DniScanDesktopOption(
            code: 'DO',
            title: 'Dorso del DNI',
            subtitle: 'Domicilio (arriba) y CUIL (centro)',
            onTap: () {
              onClose();
              onScanSide(DniScanSide.back, ImageSource.camera);
            },
          ),
          const SizedBox(height: 6),
          _DniScanDesktopOption(
            code: 'FD',
            title: 'Frente y dorso (cámara)',
            subtitle: 'Escaneo completo en dos pasos',
            onTap: () {
              onClose();
              onScanBoth(ImageSource.camera);
            },
          ),
          const SizedBox(height: 6),
          _DniScanDesktopOption(
            code: 'GA',
            title: 'Elegir foto de galería',
            subtitle: 'Una cara del DNI (frente o dorso)',
            onTap: () {
              onClose();
              onScanSide(DniScanSide.unknown, ImageSource.gallery);
            },
          ),
          const SizedBox(height: 24),
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

class _DniScanDesktopOption extends StatelessWidget {
  const _DniScanDesktopOption({
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radius),
            border: Border.all(color: AppColors.border),
          ),
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
                  code,
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
                      title,
                      style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
