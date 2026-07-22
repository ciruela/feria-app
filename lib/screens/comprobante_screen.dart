import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/budget.dart';
import '../models/budget_customer_controllers.dart';
import '../theme/app_theme.dart';
import '../utils/presupuesto_exporter.dart';
import '../utils/presupuesto_pdf.dart';
import '../widgets/feria_shell.dart';
import '../widgets/presupuesto_paper.dart';

class ComprobanteScreen extends StatefulWidget {
  const ComprobanteScreen({super.key, required this.budget});

  final Budget budget;

  @override
  State<ComprobanteScreen> createState() => _ComprobanteScreenState();
}

class _ComprobanteScreenState extends State<ComprobanteScreen> {
  late final BudgetCustomerControllers _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = BudgetCustomerControllers();
    _controllers.applyCustomer(widget.budget.customer);
  }

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  Budget get budget => widget.budget;

  Future<void> _exportPdf() async {
    try {
      await PresupuestoPdf.share(budget);
    } catch (error) {
      if (!mounted) return;
      _showMessage('No se pudo exportar el PDF: $error');
    }
  }

  Future<void> _printBudget() async {
    try {
      await PresupuestoPdf.printBudget(budget);
    } catch (error) {
      if (!mounted) return;
      _showMessage('No se pudo imprimir: $error');
    }
  }

  Future<void> _copyText() async {
    await Clipboard.setData(
      ClipboardData(text: PresupuestoExporter.toPlainText(budget)),
    );
    if (!mounted) return;
    _showMessage('Comprobante copiado');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('Comprobante'),
        leading: IconButton(
          tooltip: 'Volver al carrito',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Exportar PDF',
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Imprimir',
            onPressed: _printBudget,
            icon: const Icon(Icons.print_outlined),
          ),
          IconButton(
            tooltip: 'Copiar comprobante',
            onPressed: _copyText,
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.success.withValues(alpha: 0.15),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comprobante generado',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                        ),
                      ),
                      Text(
                        budget.customer.fullName.isEmpty
                            ? 'Revisá la hoja antes de entregarla al cliente.'
                            : 'Cliente: ${budget.customer.fullName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFE8E4DC),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Material(
                        elevation: 6,
                        shadowColor: Colors.black.withValues(alpha: 0.25),
                        color: Colors.white,
                        child: PresupuestoPaper(
                          budget: budget,
                          controllers: _controllers,
                          readOnly: true,
                          onSerialChanged: (_, __) {},
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyText,
                          icon: const Icon(Icons.copy_all_rounded),
                          label: const Text('COPIAR'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _exportPdf,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('PDF'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _printBudget,
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('IMPRIMIR'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: const Text('NUEVA VENTA'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
