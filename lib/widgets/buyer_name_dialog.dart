import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/uppercase_input.dart';

Future<String?> showBuyerNameDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _BuyerNameDialog(),
  );
}

class _BuyerNameDialog extends StatefulWidget {
  const _BuyerNameDialog();

  @override
  State<_BuyerNameDialog> createState() => _BuyerNameDialogState();
}

class _BuyerNameDialogState extends State<_BuyerNameDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person_rounded, color: AppColors.accent, size: 28),
      ),
      title: const Text('Datos del comprador'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: UpperCaseTextFormatter.formatters,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            labelText: 'Nombre y apellido',
            hintText: 'Ej: JUAN PÉREZ',
          ),
          validator: (value) {
            if (value == null || value.trim().length < 3) {
              return 'Ingresá nombre y apellido';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCELAR'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('CONTINUAR'),
        ),
      ],
    );
  }
}
