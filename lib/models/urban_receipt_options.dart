/// Opciones del recibo Urban Tactical (NGA Defense).
abstract final class UrbanReceiptOptions {
  static const paymentMethods = [
    'EF',
    'TR',
    'TC',
    'OTROS',
    'EF/TR',
    'SORTEO',
  ];

  static const fiscalConditions = [
    'Cons. final',
    'Resp. Inscrip',
  ];

  static const defaultFiscalCondition = 'Cons. final';
}
