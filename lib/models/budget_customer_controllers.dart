import 'package:flutter/material.dart';

import 'budget.dart';
import 'urban_receipt_options.dart';

class BudgetCustomerControllers {
  BudgetCustomerControllers()
      : fullName = TextEditingController(),
        dni = TextEditingController(),
        clu = TextEditingController(),
        cluExpiry = TextEditingController(),
        phone = TextEditingController(),
        email = TextEditingController(),
        fiscalCondition = TextEditingController(
          text: UrbanReceiptOptions.defaultFiscalCondition,
        ),
        address = TextEditingController(),
        city = TextEditingController(),
        notes = TextEditingController();

  final TextEditingController fullName;
  final TextEditingController dni;
  final TextEditingController clu;
  final TextEditingController cluExpiry;
  final TextEditingController phone;
  final TextEditingController email;
  final TextEditingController fiscalCondition;
  final TextEditingController address;
  final TextEditingController city;
  final TextEditingController notes;

  void applyScan({
    String? fullName,
    String? dni,
    String? cuil,
    String? address,
    String? city,
    bool useCuilAsTaxId = false,
  }) {
    if (fullName != null && fullName.isNotEmpty) {
      this.fullName.text = fullName;
    }
    if (useCuilAsTaxId && cuil != null && cuil.isNotEmpty) {
      this.dni.text = cuil;
    } else if (dni != null && dni.isNotEmpty) {
      this.dni.text = dni;
    } else if (cuil != null && cuil.isNotEmpty) {
      this.dni.text = cuil;
    }
    if (address != null && address.isNotEmpty) {
      this.address.text = address;
    }
    if (city != null && city.isNotEmpty) {
      this.city.text = city;
    }
  }

  void applyCustomer(BudgetCustomer customer) {
    fullName.text = customer.fullName;
    dni.text = customer.dni;
    clu.text = customer.clu;
    cluExpiry.text = customer.cluExpiry;
    phone.text = customer.phone;
    email.text = customer.email;
    fiscalCondition.text = customer.fiscalCondition.isNotEmpty
        ? customer.fiscalCondition
        : UrbanReceiptOptions.defaultFiscalCondition;
    address.text = customer.address;
    city.text = customer.city;
    notes.text = customer.notes;
  }

  void dispose() {
    fullName.dispose();
    dni.dispose();
    clu.dispose();
    cluExpiry.dispose();
    phone.dispose();
    email.dispose();
    fiscalCondition.dispose();
    address.dispose();
    city.dispose();
    notes.dispose();
  }
}
