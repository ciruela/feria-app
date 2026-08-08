import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/cart_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/uppercase_input.dart';
import '../employee/catalog_product_list.dart';

/// AR-40 / AR-58: N° de serie editable fuera del A4 (el preview escalado
/// no permite cargar bien el campo SERIE en mobile).
class BudgetSerialPanel extends StatelessWidget {
  const BudgetSerialPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final weapons = cart.items.where((item) => item.product.isArma).toList();
    if (weapons.isEmpty) return const SizedBox.shrink();

    final missing = cart.weaponsMissingSerial.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'N° DE SERIE',
          style: AppText.label.copyWith(
            color: AppColors.textMuted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          missing == 0
              ? 'Series cargadas. Podés generar el comprobante.'
              : 'Completá el N° de serie de cada arma para habilitar el comprobante.',
          style: AppText.bodySmall.copyWith(
            color: missing == 0 ? AppColors.textMuted : AppColors.accent,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in weapons) ...[
          _SerialLineEditor(
            key: ValueKey('panel-serial-${item.lineKey}'),
            lineKey: item.lineKey,
            label: catalogProductTitle(item.product),
            initialValue: item.serialNumber,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SerialLineEditor extends StatefulWidget {
  const _SerialLineEditor({
    super.key,
    required this.lineKey,
    required this.label,
    required this.initialValue,
  });

  final String lineKey;
  final String label;
  final String initialValue;

  @override
  State<_SerialLineEditor> createState() => _SerialLineEditorState();
}

class _SerialLineEditorState extends State<_SerialLineEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_SerialLineEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus &&
        widget.initialValue != _controller.text &&
        widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.bodySmall.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: UpperCaseTextFormatter.formatters,
          onChanged: (value) {
            context.read<CartService>().updateSerialNumber(
                  widget.lineKey,
                  value,
                  notify: true,
                );
          },
          decoration: const InputDecoration(
            labelText: 'N° de serie',
            hintText: 'Obligatorio para armas',
            isDense: true,
          ),
        ),
      ],
    );
  }
}
