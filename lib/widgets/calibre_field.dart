import 'package:flutter/material.dart';

import '../utils/uppercase_input.dart';

/// Selector de calibre: desplegable con los existentes u opción para escribir uno nuevo.
class CalibreField extends StatefulWidget {
  const CalibreField({
    super.key,
    required this.controller,
    required this.calibers,
    this.enabled = true,
  });

  final TextEditingController controller;
  final List<String> calibers;
  final bool enabled;

  static const _otherValue = '__other__';

  @override
  State<CalibreField> createState() => _CalibreFieldState();
}

class _CalibreFieldState extends State<CalibreField> {
  bool _forceCustom = false;

  bool get _showCustom {
    if (_forceCustom || widget.calibers.isEmpty) return true;
    final current = widget.controller.text.trim();
    if (current.isEmpty) return false;
    return !widget.calibers.any(
      (calibre) => calibre.toLowerCase() == current.toLowerCase(),
    );
  }

  String? get _dropdownValue {
    final current = widget.controller.text.trim();
    if (current.isEmpty) return null;

    for (final calibre in widget.calibers) {
      if (calibre.toLowerCase() == current.toLowerCase()) return calibre;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_showCustom) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: widget.controller,
            enabled: widget.enabled,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: UpperCaseTextFormatter.formatters,
            decoration: const InputDecoration(
              labelText: 'Calibre',
              border: OutlineInputBorder(),
            ),
          ),
          if (widget.calibers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.enabled
                    ? () => setState(() {
                          _forceCustom = false;
                          widget.controller.clear();
                        })
                    : null,
                child: const Text('ELEGIR DE LA LISTA'),
              ),
            ),
          ],
        ],
      );
    }

    return DropdownButtonFormField<String>(
      key: ValueKey('calibre-${widget.calibers.length}-$_dropdownValue'),
      initialValue: _dropdownValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Calibre',
        border: OutlineInputBorder(),
      ),
      hint: const Text('Seleccioná un calibre'),
      items: [
        ...widget.calibers.map(
          (calibre) => DropdownMenuItem(
            value: calibre,
            child: Text(calibre.toUpperCase()),
          ),
        ),
        const DropdownMenuItem(
          value: CalibreField._otherValue,
          child: Text('Otro calibre...'),
        ),
      ],
      onChanged: widget.enabled
          ? (value) {
              if (value == null) return;
              setState(() {
                if (value == CalibreField._otherValue) {
                  _forceCustom = true;
                  widget.controller.clear();
                } else {
                  _forceCustom = false;
                  widget.controller.text = value;
                }
              });
            }
          : null,
    );
  }
}
