import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Teclado numérico + casillas para PIN admin (handoff Cobre táctico).
class AdminPinEntry extends StatefulWidget {
  const AdminPinEntry({
    super.key,
    this.maxDigits = 4,
    this.wrong = false,
    this.onChanged,
    this.onSubmit,
  });

  final int maxDigits;
  final bool wrong;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmit;

  @override
  State<AdminPinEntry> createState() => AdminPinEntryState();
}

class AdminPinEntryState extends State<AdminPinEntry> {
  String _pin = '';

  void clear() => setState(() => _pin = '');

  String get pin => _pin;

  void _append(String digit) {
    if (_pin.length >= widget.maxDigits) return;
    setState(() => _pin += digit);
    widget.onChanged?.call(_pin);
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
    widget.onChanged?.call(_pin);
  }

  void _submit() {
    if (_pin.isEmpty) return;
    widget.onSubmit?.call(_pin);
  }

  @override
  Widget build(BuildContext context) {
    final boxColor = widget.wrong ? AppColors.accent : AppColors.border;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.maxDigits, (index) {
            final filled = index < _pin.length;
            return Container(
              width: 44,
              height: 52,
              margin: EdgeInsets.only(
                right: index < widget.maxDigits - 1 ? 10 : 0,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceTouch,
                borderRadius: BorderRadius.circular(AppDecorations.radius),
                border: Border.all(
                  color: boxColor,
                  width: widget.wrong ? 1 : AppDecorations.hairline,
                ),
              ),
              child: Text(
                filled ? '•' : '',
                style: AppText.display.copyWith(
                  color: widget.wrong ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        _Keypad(
          onDigit: _append,
          onBackspace: _backspace,
          onSubmit: _submit,
        ),
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Column(
      children: [
        for (final row in keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (final key in row) ...[
                  Expanded(child: _Key(label: key, onTap: () => onDigit(key))),
                  if (key != row.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _Key(
                icon: Icons.backspace_outlined,
                onTap: onBackspace,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _Key(label: '0', onTap: () => onDigit('0'))),
            const SizedBox(width: 8),
            Expanded(
              child: _Key(
                icon: Icons.check_rounded,
                accent: true,
                onTap: onSubmit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    this.label,
    this.icon,
    this.accent = false,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;
  final bool accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent ? AppColors.accent : AppColors.surfaceTouch,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        child: SizedBox(
          height: 64,
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    size: 22,
                    color: accent ? AppColors.onAccent : AppColors.textMuted,
                  )
                : Text(
                    label ?? '',
                    style: AppText.numberLarge.copyWith(
                      color: accent ? AppColors.onAccent : AppColors.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
