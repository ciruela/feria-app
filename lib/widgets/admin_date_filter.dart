import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';

enum AdminDateMode { dia, rango }

class AdminDateModeSelector extends StatelessWidget {
  const AdminDateModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final AdminDateMode mode;
  final ValueChanged<AdminDateMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AdminDateMode>(
      segments: const [
        ButtonSegment(value: AdminDateMode.dia, label: Text('Un día')),
        ButtonSegment(value: AdminDateMode.rango, label: Text('Rango')),
      ],
      selected: {mode},
      onSelectionChanged: (values) => onChanged(values.first),
    );
  }
}

class AdminRangeChips extends StatelessWidget {
  const AdminRangeChips({
    super.key,
    required this.from,
    required this.to,
    required this.onPickFrom,
    required this.onPickTo,
  });

  final DateTime from;
  final DateTime to;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AdminDateChip(label: 'Desde', date: from, onTap: onPickFrom),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AdminDateChip(label: 'Hasta', date: to, onTap: onPickTo),
        ),
      ],
    );
  }
}

class AdminDateChip extends StatelessWidget {
  const AdminDateChip({
    super.key,
    required this.date,
    required this.onTap,
    this.label,
    this.showTodayLabel = true,
  });

  final DateTime date;
  final VoidCallback onTap;
  final String? label;
  final bool showTodayLabel;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(date, DateTime.now());
    final dateLabel = label != null
        ? '$label · ${formatDate(date)}'
        : (showTodayLabel && isToday
            ? 'Hoy · ${formatDate(date)}'
            : formatDate(date));

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded, color: AppColors.goldDark),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dateLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const Icon(
                Icons.edit_calendar_outlined,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
