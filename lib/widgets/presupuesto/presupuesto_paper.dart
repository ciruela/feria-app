import 'package:flutter/material.dart';

import '../../models/budget.dart';
import '../../models/budget_customer_controllers.dart';
import '../../models/presupuesto_document.dart';
import 'presupuesto_customer_fields.dart';
import 'presupuesto_header.dart';
import 'presupuesto_items_table.dart';
import 'presupuesto_payment_section.dart';

class PresupuestoPaper extends StatelessWidget {
  const PresupuestoPaper({
    super.key,
    required this.budget,
    required this.controllers,
    required this.onSerialChanged,
    this.readOnly = false,
    this.onChanged,
  });

  final Budget budget;
  final BudgetCustomerControllers controllers;
  final void Function(String lineKey, String value) onSerialChanged;
  final bool readOnly;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final document = PresupuestoDocument.fromBudget(budget);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PresupuestoHeader(
            day: document.day,
            month: document.month,
            year: document.year,
          ),
          const SizedBox(height: 10),
          PresupuestoCustomerFields(
            controllers: controllers,
            readOnly: readOnly,
            onChanged: onChanged,
          ),
          const SizedBox(height: 8),
          PresupuestoItemsTable(
            rows: document.tableRows,
            readOnly: readOnly,
            onSerialChanged: onSerialChanged,
          ),
          const SizedBox(height: 8),
          PresupuestoTotalsSection(summary: document.summary),
          const SizedBox(height: 8),
          PresupuestoPaymentSection(summary: document.summary),
          const SizedBox(height: 8),
          PresupuestoLabeledField(
            label: 'OBS:',
            controller: controllers.notes,
            readOnly: readOnly,
            onChanged: onChanged,
            minLines: 2,
          ),
          if (document.sellerName != null) ...[
            const SizedBox(height: 8),
            Text(
              'Atendido por: ${document.sellerName}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}
