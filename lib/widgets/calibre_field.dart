import 'package:flutter/material.dart';

import '../data/common_calibers.dart';
import '../theme/app_theme.dart';
import '../utils/uppercase_input.dart';

/// Calibre: siempre editable, con sugerencias y atajos de calibres comunes.
class CalibreField extends StatelessWidget {
  const CalibreField({
    super.key,
    required this.controller,
    required this.calibers,
    this.enabled = true,
  });

  final TextEditingController controller;
  final List<String> calibers;
  final bool enabled;

  List<String> get _options => CommonCalibers.mergedWith(calibers);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Autocomplete<String>(
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) return _options;
            return _options.where(
              (calibre) => calibre.toLowerCase().contains(query),
            );
          },
          onSelected: enabled
              ? (selection) {
                  controller.text = selection;
                  controller.selection = TextSelection.collapsed(
                    offset: selection.length,
                  );
                }
              : null,
          fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: UpperCaseTextFormatter.formatters,
              decoration: const InputDecoration(
                labelText: 'Calibre',
                hintText: 'Escribí o elegí de la lista',
                border: OutlineInputBorder(),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            if (options.isEmpty) return const SizedBox.shrink();

            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220, maxWidth: 400),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final calibre = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(calibre),
                        onTap: () => onSelected(calibre),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          'Calibres comunes',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final calibre in CommonCalibers.quickPick)
              ActionChip(
                label: Text(calibre),
                onPressed: enabled
                    ? () {
                        controller.text = calibre;
                        controller.selection = TextSelection.collapsed(
                          offset: calibre.length,
                        );
                      }
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}
