import '../utils/tenant_slug.dart';

/// Layout del comprobante / presupuesto según el tenant.
enum PresupuestoTemplateKind {
  /// Formato World Guns (6 columnas, logo, checks de pago).
  worldGuns,

  /// Formato Urban Tactical / NGA Defense (recibo, 3 columnas, firma).
  urbanTactical,

  /// Formato estándar para armerías nuevas (misma estructura que World Guns, datos genéricos).
  standard,
}

/// Branding y reglas de layout por tenant.
class PresupuestoBranding {
  const PresupuestoBranding({
    required this.kind,
    required this.slug,
    required this.companyName,
    required this.businessLine,
    required this.servicesLine,
    required this.addressLine,
    required this.phoneLine,
    required this.adminLine,
    required this.documentTitle,
    required this.documentSubtitle,
    required this.footerNote,
    required this.paperRows,
    required this.tableHeaders,
    required this.paymentAllocationTitle,
    required this.creditCardsTitle,
    this.logoText = '',
    this.taxLine = '',
    this.urbanStatusChecks = const [],
    this.signatureLine = '',
    this.useSingleDateLine = false,
    this.watermarkLogoAsset,
  });

  static const worldGunsSlug = 'world-guns';
  static const urbanTacticalSlug = 'urban-tactical';
  static const urbanWatermarkAsset =
      'assets/branding/urban_tactical_watermark_color.png';

  final PresupuestoTemplateKind kind;
  final String slug;
  final String companyName;
  final String businessLine;
  final String servicesLine;
  final String addressLine;
  final String phoneLine;
  final String adminLine;
  final String documentTitle;
  final String documentSubtitle;
  final String footerNote;
  final int paperRows;
  final List<String> tableHeaders;
  final String paymentAllocationTitle;
  final String creditCardsTitle;
  final String logoText;
  final String taxLine;
  final List<String> urbanStatusChecks;
  final String signatureLine;
  final bool useSingleDateLine;
  final String? watermarkLogoAsset;

  bool get isUrban => kind == PresupuestoTemplateKind.urbanTactical;
  bool get isWorldGuns => kind == PresupuestoTemplateKind.worldGuns;
  bool get showsDetailedTable => tableHeaders.length > 3;
  bool get showsPaymentChecks => !isUrban;
  bool get showsWorldGunsLogo => isWorldGuns;

  /// Resuelve el template según slug del tenant activo.
  static PresupuestoBranding forTenant({
    String? slug,
    String? displayName,
  }) {
    final key = tenantSlugKey(slug ?? '');
    if (tenantSlugMatches(key, worldGunsSlug)) return worldGuns;
    if (tenantSlugMatches(key, urbanTacticalSlug)) return urbanTactical;
    return standard(displayName ?? 'Armería');
  }

  static const worldGuns = PresupuestoBranding(
    kind: PresupuestoTemplateKind.worldGuns,
    slug: worldGunsSlug,
    companyName: 'WORLD GUNS S.R.L.',
    businessLine: 'ARMERIA - CUCHILLERIA - ACCESORIOS',
    servicesLine: 'GESTORIA ANMAC P/CIVILES - FUERZAS-EMPRESAS',
    addressLine: 'Triunvirato 2589 1 Piso (Villa Luzuriaga - Pcia. Bs.As.)',
    phoneLine: 'Tel: 4835-9420  Ventas WApp: 11-3864-4279',
    adminLine: 'Adm./Gestoria WApp: 11-5147-1705  @wordguns.srl',
    documentTitle: 'PRESUPUESTO',
    documentSubtitle: '(DOC. NO VALIDO COMO FACTURA)',
    footerNote:
        'Horario: Lun a Vie 10 a 13 y 15:30 a 19 · Sab 10 a 13\n'
        'Los precios pueden variar sin previo aviso.\n'
        'Reserva de mercaderia con seña del 30%.',
    paperRows: 14,
    tableHeaders: ['COD', 'CANT', 'DETALLE', 'TC', 'P. UNIT', 'IMPORTE'],
    paymentAllocationTitle: 'FORMA DE PAGO ACORDADA',
    creditCardsTitle: 'TARJETAS DE CREDITO',
    logoText: 'WORLD\nGUNS',
  );

  static const urbanTactical = PresupuestoBranding(
    kind: PresupuestoTemplateKind.urbanTactical,
    slug: urbanTacticalSlug,
    companyName: 'NGA DEFENSE S.A. UCOM: 9736635',
    businessLine: '',
    servicesLine: '',
    addressLine: '12 DE Octubre Nro. 1595 Pilar – Buenos Aires',
    phoneLine: 'Tel: 1168257250 / 1126934666',
    adminLine: '',
    taxLine: 'IVA RESPONSABLE INSCRIPTO',
    documentTitle: 'RECIBO VENTAS NUEVAS',
    documentSubtitle: 'Documento no válido como factura',
    footerNote: '',
    paperRows: 10,
    tableHeaders: ['Concepto', 'Cant', 'Valor'],
    paymentAllocationTitle: '',
    creditCardsTitle: '',
    useSingleDateLine: true,
    urbanStatusChecks: [
      'F/F',
      'ENVIO TENENCIA',
      'ENVIADO EXPRES',
      'DDB',
      'ACEPTADO',
      'RETIRADO/DESPACHADO',
    ],
    signatureLine:
        'RECIBÍ CONFORME EL MATERIAL DETALLADO EN EL PRESENTE DOCUMENTO',
    watermarkLogoAsset: urbanWatermarkAsset,
  );

  static PresupuestoBranding standard(String displayName) {
    final name = displayName.trim().isEmpty ? 'Armería' : displayName.trim();
    return PresupuestoBranding(
      kind: PresupuestoTemplateKind.standard,
      slug: slugifyTenantName(name),
      companyName: name.toUpperCase(),
      businessLine: 'ARMERÍA',
      servicesLine: '',
      addressLine: '—',
      phoneLine: 'Tel: —',
      adminLine: '',
      documentTitle: 'PRESUPUESTO',
      documentSubtitle: '(DOC. NO VÁLIDO COMO FACTURA)',
      footerNote: 'Los precios pueden variar sin previo aviso.',
      paperRows: 14,
      tableHeaders: const [
        'COD',
        'CANT',
        'DETALLE',
        'TC',
        'P. UNIT',
        'IMPORTE',
      ],
      paymentAllocationTitle: 'FORMA DE PAGO ACORDADA',
      creditCardsTitle: 'TARJETAS DE CRÉDITO',
      logoText: _initialsForLogo(name),
    );
  }

  String get fileNamePrefix {
    if (isWorldGuns) return 'presupuesto-worldguns';
    if (isUrban) return 'recibo-urban-tactical';
    return 'presupuesto-$slug';
  }

  static String _initialsForLogo(String name) {
    final words =
        name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (words.isEmpty) return 'AR';
    if (words.length == 1) {
      final word = words.first.toUpperCase();
      return word.length >= 2 ? word.substring(0, 2) : word;
    }
    return words
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
  }
}
