import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/budget.dart';
import '../../models/budget_customer_controllers.dart';
import '../../models/presupuesto_document.dart';
import '../../services/tenant_session_service.dart';
import '../../utils/presupuesto_page_format.dart';
import 'presupuesto_customer_fields.dart';
import 'presupuesto_header.dart';
import 'presupuesto_items_table.dart';
import 'presupuesto_paper_theme.dart';
import 'presupuesto_payment_section.dart';
import 'presupuesto_urban_paper.dart';

class PresupuestoPaper extends StatelessWidget {
  const PresupuestoPaper({
    super.key,
    required this.budget,
    required this.controllers,
    required this.onSerialChanged,
    required this.onTcChanged,
    this.branding,
    this.readOnly = false,
    this.onChanged,
  });

  final Budget budget;
  final BudgetCustomerControllers controllers;
  final void Function(String lineKey, String value) onSerialChanged;
  final void Function(String lineKey, String value) onTcChanged;
  final PresupuestoBranding? branding;
  final bool readOnly;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final resolvedBranding = branding ?? _brandingFromContext(context);
    final document = PresupuestoDocument.fromBudget(
      budget,
      branding: resolvedBranding,
    );

    return SizedBox(
      width: PresupuestoPageFormat.sheetWidth,
      height: PresupuestoPageFormat.sheetHeight,
      child: ColoredBox(
        color: Colors.white,
        child: PresupuestoPaperTheme(
          child: Padding(
            padding: PresupuestoPageFormat.pageMargins,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Padding(
                padding: PresupuestoPageFormat.borderPaddingInsets,
                child: resolvedBranding.isUrban
                    ? PresupuestoUrbanPaper(
                        document: document,
                        controllers: controllers,
                        readOnly: readOnly,
                        onSerialChanged: onSerialChanged,
                        onChanged: onChanged,
                      )
                    : _StandardPresupuestoBody(
                        document: document,
                        controllers: controllers,
                        readOnly: readOnly,
                        onSerialChanged: onSerialChanged,
                        onTcChanged: onTcChanged,
                        onChanged: onChanged,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static PresupuestoBranding _brandingFromContext(BuildContext context) {
    final session = context.read<TenantSessionService>();
    return PresupuestoBranding.forTenant(
      slug: session.activeTenantSlug,
      displayName: session.activeTenantDisplayName,
    );
  }
}

class _StandardPresupuestoBody extends StatelessWidget {
  const _StandardPresupuestoBody({
    required this.document,
    required this.controllers,
    required this.readOnly,
    required this.onSerialChanged,
    required this.onTcChanged,
    this.onChanged,
  });

  final PresupuestoDocument document;
  final BudgetCustomerControllers controllers;
  final bool readOnly;
  final void Function(String lineKey, String value) onSerialChanged;
  final void Function(String lineKey, String value) onTcChanged;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final branding = document.branding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PresupuestoHeader(
          branding: branding,
          day: document.day,
          month: document.month,
          year: document.year,
          formattedDate: document.formattedDate,
        ),
        const SizedBox(height: 8),
        PresupuestoCustomerFields(
          controllers: controllers,
          readOnly: readOnly,
          onChanged: onChanged,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return PresupuestoItemsTable(
                branding: branding,
                rows: document.tableRows,
                readOnly: readOnly,
                onSerialChanged: onSerialChanged,
                onTcChanged: onTcChanged,
                bodyHeight: constraints.maxHeight,
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        PresupuestoTotalsSection(summary: document.summary),
        const SizedBox(height: 6),
        PresupuestoPaymentSection(
          branding: branding,
          summary: document.summary,
        ),
        const SizedBox(height: 6),
        PresupuestoLabeledField(
          label: 'OBS:',
          controller: controllers.notes,
          readOnly: readOnly,
          onChanged: onChanged,
          minLines: 2,
        ),
        if (document.sellerName != null) ...[
          const SizedBox(height: 6),
          Text(
            'Atendido por: ${document.sellerName}',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }
}

PresupuestoBranding resolvePresupuestoBranding(TenantSessionService session) {
  return PresupuestoBranding.forTenant(
    slug: session.activeTenantSlug,
    displayName: session.activeTenantDisplayName,
  );
}
