import 'package:flutter/material.dart';

import '../../models/budget_customer_controllers.dart';
import '../../utils/uppercase_input.dart';

class PresupuestoLabeledField extends StatelessWidget {
  const PresupuestoLabeledField({
    super.key,
    required this.label,
    required this.controller,
    required this.readOnly,
    this.onChanged,
    this.minLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final VoidCallback? onChanged;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              minLines: minLines,
              maxLines: minLines,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: UpperCaseTextFormatter.formatters,
              onChanged: (_) => onChanged?.call(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.only(bottom: 2),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 1.2),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 1.2),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PresupuestoCustomerFields extends StatelessWidget {
  const PresupuestoCustomerFields({
    super.key,
    required this.controllers,
    required this.readOnly,
    this.onChanged,
  });

  final BudgetCustomerControllers controllers;
  final bool readOnly;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PresupuestoLabeledField(
          label: 'SEÑOR/A:',
          controller: controllers.fullName,
          readOnly: readOnly,
          onChanged: onChanged,
        ),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: PresupuestoLabeledField(
                label: 'DNI:',
                controller: controllers.dni,
                readOnly: readOnly,
                onChanged: onChanged,
              ),
            ),
            Expanded(
              child: PresupuestoLabeledField(
                label: 'CLU:',
                controller: controllers.clu,
                readOnly: readOnly,
                onChanged: onChanged,
              ),
            ),
            Expanded(
              child: PresupuestoLabeledField(
                label: 'VTO:',
                controller: controllers.cluExpiry,
                readOnly: readOnly,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: PresupuestoLabeledField(
                label: 'TEL:',
                controller: controllers.phone,
                readOnly: readOnly,
                onChanged: onChanged,
              ),
            ),
            Expanded(
              child: PresupuestoLabeledField(
                label: 'MAIL:',
                controller: controllers.email,
                readOnly: readOnly,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: PresupuestoLabeledField(
                label: 'DOMICILIO:',
                controller: controllers.address,
                readOnly: readOnly,
                onChanged: onChanged,
              ),
            ),
            Expanded(
              flex: 2,
              child: PresupuestoLabeledField(
                label: 'LOCALIDAD:',
                controller: controllers.city,
                readOnly: readOnly,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
