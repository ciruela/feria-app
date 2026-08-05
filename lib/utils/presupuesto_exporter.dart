import '../models/budget.dart';
import '../models/presupuesto_branding.dart';
import '../models/presupuesto_summary.dart';
import '../models/product_prices.dart';
import 'formatters.dart';

class PresupuestoExporter {
  static String toPlainText(
    Budget budget, {
    required PresupuestoBranding branding,
  }) {
    if (branding.isUrban) {
      return _urbanPlainText(budget, branding);
    }
    return _standardPlainText(budget, branding);
  }

  static String _standardPlainText(
    Budget budget,
    PresupuestoBranding branding,
  ) {
    final buffer = StringBuffer()
      ..writeln(branding.companyName)
      ..writeln('${branding.documentTitle} ${branding.documentSubtitle}')
      ..writeln('Fecha: ${formatDate(budget.date)}')
      ..writeln('')
      ..writeln('SEÑOR/A: ${_value(budget.customer.fullName)}')
      ..writeln(
        'DNI: ${_value(budget.customer.dni)}   '
        'CLU: ${_value(budget.customer.clu)}   '
        'VTO: ${_value(budget.customer.cluExpiry)}',
      )
      ..writeln(
        'TEL: ${_value(budget.customer.phone)}   '
        'MAIL: ${_value(budget.customer.email)}',
      )
      ..writeln(
        'DOMICILIO: ${_value(budget.customer.address)}   '
        'LOCALIDAD: ${_value(budget.customer.city)}',
      );

    if (budget.sellerName != null) {
      buffer.writeln('Vendedor: ${budget.sellerName}');
    }

    buffer
      ..writeln('')
      ..writeln(branding.tableHeaders.join('\t'));

    for (final line in budget.lines) {
      buffer.writeln(
        '${line.code}\t${line.quantity}\t${line.detail}\t'
        '${line.tarjetaConsumo}\t'
        '${line.formattedUnit}\t${line.formattedLine}',
      );
    }

    final emptyRows = branding.paperRows - budget.lines.length;
    for (var i = 0; i < emptyRows; i++) {
      buffer.writeln('\t\t\t\t\t');
    }

    buffer.writeln('');
    if (budget.hasUsdPayments) {
      buffer.writeln('TOTAL ${formatUsd(budget.totalUsdLines)}');
    }
    if (budget.hasArsPayments) {
      buffer.writeln('TOTAL ${formatArs(budget.totalArsLines)}');
    }
    buffer
      ..writeln('OBS: ${_value(budget.customer.notes)}')
      ..writeln('')
      ..writeln(_paymentLine(budget.paymentMethods));

    return buffer.toString();
  }

  static String _urbanPlainText(Budget budget, PresupuestoBranding branding) {
    final summary = PresupuestoSummary(budget);

    final buffer = StringBuffer()
      ..writeln(branding.companyName)
      ..writeln(branding.addressLine)
      ..writeln(branding.taxLine)
      ..writeln(branding.phoneLine)
      ..writeln('')
      ..writeln(branding.documentTitle)
      ..writeln(branding.documentSubtitle)
      ..writeln('Fecha: ${formatDate(budget.date)}')
      ..writeln('')
      ..writeln('CLIENTE: ${_value(budget.customer.fullName)}')
      ..writeln('NRO CLU: ${_value(budget.customer.clu)}')
      ..writeln('TELEFONO: ${_value(budget.customer.phone)}')
      ..writeln('DOMICILIO: ${_value(budget.customer.domicilioLine)}')
      ..writeln('MÉTODO DE PAGO: ${summary.paymentAbbrevFor(branding)}')
      ..writeln('CUIT: ${_value(budget.customer.dni)}')
      ..writeln(
        'CONDICION FISCAL: ${_value(summary.fiscalConditionFor(branding))}',
      )
      ..writeln('Obs: ${_value(budget.customer.notes)}')
      ..writeln('')
      ..writeln('Concepto\tCant\tValor');

    for (final line in budget.lines) {
      buffer.writeln(
        '${line.detail}\t${line.quantity}\t${line.formattedLinePlain}',
      );
    }

    buffer.writeln('');
    if (budget.hasArsPayments) {
      buffer.writeln('Total: ${formatArs(budget.totalArsLines)}');
    }
    if (budget.hasUsdPayments) {
      buffer.writeln('Total: ${formatUsd(budget.totalUsdLines)}');
    }

    return buffer.toString();
  }

  static String _value(String value) => value.isEmpty ? '—' : value;

  static String _paymentLine(Set<PaymentMethod> methods) {
    final parts = <String>[];
    void add(String label, bool checked) {
      parts.add('${checked ? '[X]' : '[ ]'} $label');
    }

    add('EFVO.', methods.contains(PaymentMethod.efectivo));
    add('DEBITO', methods.contains(PaymentMethod.debito));
    add('TRANSFERENCIA', methods.contains(PaymentMethod.transferencia));
    add('PESOS', _usesPesos(methods));
    add('U\$s', methods.contains(PaymentMethod.dolarBillete));
    add('1 CTA', methods.contains(PaymentMethod.tarjeta1));
    add('3 CTAS', methods.contains(PaymentMethod.tarjeta3));
    add('6 CTAS', methods.contains(PaymentMethod.tarjeta6));
    add('9 CTAS', methods.contains(PaymentMethod.tarjeta9));
    add('12 CTAS', methods.contains(PaymentMethod.tarjeta12));
    add('18 CTAS', methods.contains(PaymentMethod.tarjeta18));

    return parts.join('  ');
  }

  static bool _usesPesos(Set<PaymentMethod> methods) {
    return methods.contains(PaymentMethod.lista) ||
        methods.contains(PaymentMethod.transferencia) ||
        methods.contains(PaymentMethod.efectivo) ||
        methods.contains(PaymentMethod.debito) ||
        methods.any((method) => method.name.startsWith('tarjeta'));
  }
}
