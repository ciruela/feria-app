/// Intención de registro persistida en Supabase user_metadata.
class RegistrationIntent {
  const RegistrationIntent._();

  static const key = 'registration_intent';
  static const createOrganization = 'create_organization';
  static const companyNameKey = 'company_name';
  static const fullNameKey = 'full_name';

  /// SharedPreferences: el usuario registró org pero aún no confirmó email.
  static const prefsAwaitingOrgKey = 'awaiting_org_registration';

  static bool hasCreateOrganizationIntent(Map<String, dynamic>? metadata) {
    if (metadata == null) return false;
    return metadata[key]?.toString() == createOrganization;
  }

  static String? companyNameFrom(Map<String, dynamic>? metadata) {
    final name = metadata?[companyNameKey]?.toString().trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  static Map<String, dynamic> signUpMetadata({
    required String companyName,
    required String fullName,
  }) {
    return {
      key: createOrganization,
      companyNameKey: companyName.trim(),
      fullNameKey: fullName.trim(),
    };
  }
}

/// Decide si el bootstrap debe llamar a provision_my_tenant tras cargar memberships.
bool shouldProvisionOrganization({
  required bool hasCreateOrganizationIntent,
  required int activeMembershipCount,
}) {
  return hasCreateOrganizationIntent && activeMembershipCount == 0;
}

/// Cuenta autenticada sin acceso a ninguna armería ni panel de plataforma.
bool computeHasNoOrganizationAccess({
  required bool membershipsLoaded,
  required int membershipCount,
  required bool isPlatformAdmin,
  required bool isTenantViewNone,
}) {
  return membershipsLoaded &&
      membershipCount == 0 &&
      !isPlatformAdmin &&
      isTenantViewNone;
}

int computeDestinationCount({
  required int membershipCount,
  required bool isPlatformAdmin,
}) {
  return membershipCount + (isPlatformAdmin ? 1 : 0);
}
