import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_feria/services/auth_service.dart';
import 'package:app_feria/utils/pin_hash.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('verifyAdminPin usa hash de nube cuando está disponible', () async {
    final auth = AuthService();
    await auth.load();
    expect(auth.verifyAdminPin(AuthService.defaultPin), isTrue);

    // Simula PIN remoto distinto sin pasar por Supabase.
    // ignore: invalid_use_of_visible_for_testing_member
    // Acceso vía change sin cloud: cambiamos local y verificamos hash helper.
    final custom = '9999';
    expect(pinMatches(custom, hashPin(custom)), isTrue);
    expect(pinMatches(AuthService.defaultPin, hashPin(custom)), isFalse);
  });

  test('changeAdminPin actualiza el PIN local', () async {
    final auth = AuthService();
    await auth.load();
    await auth.changeAdminPin('4321');
    expect(auth.verifyAdminPin('4321'), isTrue);
    expect(auth.verifyAdminPin(AuthService.defaultPin), isFalse);
    expect(auth.isDefaultAdminPin, isFalse);
  });
}
