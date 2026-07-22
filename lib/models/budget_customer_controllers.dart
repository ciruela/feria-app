import 'package:flutter/material.dart';

import 'budget.dart';

class BudgetCustomerControllers {
  BudgetCustomerControllers()
      : fullName = TextEditingController(),
        dni = TextEditingController(),
        clu = TextEditingController(),
        cluExpiry = TextEditingController(),
        phone = TextEditingController(),
        email = TextEditingController(),
        address = TextEditingController(),
        city = TextEditingController(),
        notes = TextEditingController();

  final TextEditingController fullName;
  final TextEditingController dni;
  final TextEditingController clu;
  final TextEditingController cluExpiry;
  final TextEditingController phone;
  final TextEditingController email;
  final TextEditingController address;
  final TextEditingController city;
  final TextEditingController notes;

  void applyScan({
    String? fullName,
    String? dni,
    String? address,
    String? city,
  }) {
    if (fullName != null && fullName.isNotEmpty) {
      this.fullName.text = fullName;
    }
    if (dni != null && dni.isNotEmpty) {
      this.dni.text = dni;
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
    address.dispose();
    city.dispose();
    notes.dispose();
  }
}
