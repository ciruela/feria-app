import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FilterChipButton extends StatelessWidget {
  const FilterChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 18,
            vertical: compact ? 10 : 16,
          ),
          decoration: BoxDecoration(
            gradient: selected
                ? AppDecorations.appBarGradient
                : null,
            color: selected ? null : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 15 : 17,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class LetterChip extends StatelessWidget {
  const LetterChip({
    super.key,
    required this.letter,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String letter;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: selected ? AppDecorations.goldGradient : null,
              color: !enabled
                  ? AppColors.backgroundDark
                  : selected
                      ? null
                      : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.goldDark
                    : enabled
                        ? AppColors.border
                        : AppColors.border.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: !enabled
                    ? AppColors.textSecondary.withValues(alpha: 0.35)
                    : selected
                        ? AppColors.primaryDark
                        : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LetterGrid extends StatelessWidget {
  const LetterGrid({
    super.key,
    required this.onLetterTap,
    this.enabledLetters,
  });

  final ValueChanged<String> onLetterTap;
  final Set<String>? enabledLetters;

  @override
  Widget build(BuildContext context) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: letters.split('').map((letter) {
        final enabled =
            enabledLetters == null || enabledLetters!.contains(letter);

        return SizedBox(
          width: 56,
          height: 56,
          child: OutlinedButton(
            onPressed: enabled ? () => onLetterTap(letter) : null,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor:
                  enabled ? AppColors.surface : AppColors.backgroundDark,
            ),
            child: Text(letter),
          ),
        );
      }).toList(),
    );
  }
}
