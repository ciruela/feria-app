import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_feria/auth/registration_intent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('email confirmation intent persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('prefs flag sobrevive recarga de app', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(RegistrationIntent.prefsAwaitingOrgKey, true);

      final reloaded = await SharedPreferences.getInstance();
      expect(reloaded.getBool(RegistrationIntent.prefsAwaitingOrgKey), isTrue);
    });

    test('limpiar flag tras confirmacion simulada', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(RegistrationIntent.prefsAwaitingOrgKey, true);
      await prefs.remove(RegistrationIntent.prefsAwaitingOrgKey);

      expect(prefs.getBool(RegistrationIntent.prefsAwaitingOrgKey), isNull);
    });
  });
}
