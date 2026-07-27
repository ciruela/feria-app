import 'package:app_feria/auth/registration_intent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RegistrationIntent', () {
    test('detecta intencion create_organization', () {
      expect(
        RegistrationIntent.hasCreateOrganizationIntent({
          RegistrationIntent.key: RegistrationIntent.createOrganization,
          RegistrationIntent.companyNameKey: 'World Guns',
        }),
        isTrue,
      );
      expect(
        RegistrationIntent.hasCreateOrganizationIntent({'company_name': 'X'}),
        isFalse,
      );
      expect(RegistrationIntent.hasCreateOrganizationIntent(null), isFalse);
    });

    test('signUpMetadata incluye campos requeridos', () {
      final meta = RegistrationIntent.signUpMetadata(
        companyName: 'Pepe Armas',
        fullName: 'Pepe López',
      );
      expect(meta[RegistrationIntent.key], RegistrationIntent.createOrganization);
      expect(meta[RegistrationIntent.companyNameKey], 'Pepe Armas');
      expect(meta[RegistrationIntent.fullNameKey], 'Pepe López');
    });

    test('companyNameFrom lee metadata', () {
      expect(
        RegistrationIntent.companyNameFrom({
          RegistrationIntent.companyNameKey: '  Mi Shop  ',
        }),
        'Mi Shop',
      );
    });
  });

  group('shouldProvisionOrganization', () {
    test('login sin intent no provisiona', () {
      expect(
        shouldProvisionOrganization(
          hasCreateOrganizationIntent: false,
          activeMembershipCount: 0,
        ),
        isFalse,
      );
    });

    test('registro de org sin membership provisiona', () {
      expect(
        shouldProvisionOrganization(
          hasCreateOrganizationIntent: true,
          activeMembershipCount: 0,
        ),
        isTrue,
      );
    });

    test('cuenta con membership no reprovisiona aunque quede intent', () {
      expect(
        shouldProvisionOrganization(
          hasCreateOrganizationIntent: true,
          activeMembershipCount: 1,
        ),
        isFalse,
      );
    });
  });

  group('computeHasNoOrganizationAccess', () {
    test('login sin memberships muestra pantalla sin org', () {
      expect(
        computeHasNoOrganizationAccess(
          membershipsLoaded: true,
          membershipCount: 0,
          isPlatformAdmin: false,
          isTenantViewNone: true,
        ),
        isTrue,
      );
    });

    test('super admin sin memberships entra al panel', () {
      expect(
        computeHasNoOrganizationAccess(
          membershipsLoaded: true,
          membershipCount: 0,
          isPlatformAdmin: true,
          isTenantViewNone: true,
        ),
        isFalse,
      );
    });

    test('usuario con una membership no ve pantalla sin org', () {
      expect(
        computeHasNoOrganizationAccess(
          membershipsLoaded: true,
          membershipCount: 1,
          isPlatformAdmin: false,
          isTenantViewNone: true,
        ),
        isFalse,
      );
    });
  });

  group('computeDestinationCount', () {
    test('una membership entra directo', () {
      expect(
        computeDestinationCount(membershipCount: 1, isPlatformAdmin: false),
        1,
      );
    });

    test('varias memberships muestran selector', () {
      expect(
        computeDestinationCount(membershipCount: 2, isPlatformAdmin: false),
        2,
      );
    });

    test('platform admin sin memberships tiene un destino', () {
      expect(
        computeDestinationCount(membershipCount: 0, isPlatformAdmin: true),
        1,
      );
    });

    test('world guns owner + platform admin tiene dos destinos', () {
      expect(
        computeDestinationCount(membershipCount: 1, isPlatformAdmin: true),
        2,
      );
    });
  });
}
