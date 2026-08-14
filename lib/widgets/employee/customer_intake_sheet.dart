import 'package:flutter/material.dart';

import '../../models/customer_record.dart';
import '../../services/customer_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/layout_breakpoints.dart';
import '../../utils/uppercase_input.dart';

typedef CustomerIntakeApply = void Function(CustomerRecord record);
typedef CustomerIntakeVoid = void Function();

/// Al generar comprobante: ¿cliente que ya compró o cliente nuevo?
Future<void> showCustomerIntakeSheet(
  BuildContext context, {
  required bool useCuilAsTaxId,
  required CustomerRepository repository,
  required CustomerIntakeApply onExistingCustomer,
  CustomerIntakeVoid? onNewCustomer,
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
          side: const BorderSide(
            color: AppColors.border,
            width: AppDecorations.hairline,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _CustomerIntakeContent(
            useCuilAsTaxId: useCuilAsTaxId,
            repository: repository,
            onExistingCustomer: onExistingCustomer,
            onNewCustomer: onNewCustomer,
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
    isDismissible: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDecorations.radiusSheet),
      ),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: _CustomerIntakeContent(
        useCuilAsTaxId: useCuilAsTaxId,
        repository: repository,
        onExistingCustomer: onExistingCustomer,
        onNewCustomer: onNewCustomer,
        onClose: () => Navigator.pop(context),
      ),
    ),
  );
}

class _CustomerIntakeContent extends StatefulWidget {
  const _CustomerIntakeContent({
    required this.useCuilAsTaxId,
    required this.repository,
    required this.onExistingCustomer,
    required this.onClose,
    this.onNewCustomer,
  });

  final bool useCuilAsTaxId;
  final CustomerRepository repository;
  final CustomerIntakeApply onExistingCustomer;
  final CustomerIntakeVoid? onNewCustomer;
  final VoidCallback onClose;

  @override
  State<_CustomerIntakeContent> createState() => _CustomerIntakeContentState();
}

class _CustomerIntakeContentState extends State<_CustomerIntakeContent> {
  final _dniController = TextEditingController();
  bool _showLookup = false;
  bool _searching = false;
  String? _error;

  String get _taxIdLabel =>
      widget.useCuilAsTaxId ? 'CUIT / CUIL' : 'DNI';

  @override
  void dispose() {
    _dniController.dispose();
    super.dispose();
  }

  Future<void> _searchExisting() async {
    final dni = _dniController.text.trim();
    final norm = normalizeDni(dni);
    if (norm.length < 6) {
      setState(() => _error = 'Ingresá un $_taxIdLabel válido (mínimo 6 dígitos).');
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final record = await widget.repository.lookupByDni(dni);
      if (!mounted) return;
      if (record == null) {
        setState(() {
          _searching = false;
          _error =
              'No encontramos un cliente con ese $_taxIdLabel. Podés cargarlo como cliente nuevo.';
        });
        return;
      }

      widget.onExistingCustomer(record);
      widget.onClose();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'No se pudo buscar: $error';
      });
    }
  }

  void _chooseNew() {
    widget.onNewCustomer?.call();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '¿Quién compra?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Si ya compró antes, buscá por $_taxIdLabel y cargamos los datos en el comprobante.',
              style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            if (!_showLookup) ...[
              _ChoiceTile(
                icon: Icons.person_search_outlined,
                title: 'Ya es cliente',
                subtitle: 'Buscar por $_taxIdLabel y autocompletar',
                onTap: () => setState(() => _showLookup = true),
              ),
              const SizedBox(height: 10),
              _ChoiceTile(
                icon: Icons.person_add_alt_1_outlined,
                title: 'Cliente nuevo',
                subtitle: 'Escanear DNI o completar a mano',
                onTap: _chooseNew,
              ),
            ] else ...[
              TextField(
                controller: _dniController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.number,
                inputFormatters: UpperCaseTextFormatter.formatters,
                decoration: InputDecoration(
                  labelText: _taxIdLabel,
                  hintText: widget.useCuilAsTaxId ? 'Ej: 20-12345678-9' : 'Ej: 12345678',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                onSubmitted: (_) => _searchExisting(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: _searching
                        ? null
                        : () => setState(() {
                              _showLookup = false;
                              _error = null;
                            }),
                    child: const Text('VOLVER'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _searching ? null : _searchExisting,
                    icon: _searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search_rounded, size: 18),
                    label: const Text('BUSCAR CLIENTE'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: _searching ? null : _chooseNew,
                  child: const Text('No está en la base → cliente nuevo'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppDecorations.radiusMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDecorations.radiusMd,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppDecorations.radiusMd,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppText.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
