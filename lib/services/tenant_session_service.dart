import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/registration_intent.dart';
import '../config/app_config.dart';
import '../utils/app_logger.dart';
import '../utils/jwt.dart';
import 'supabase_service.dart';

/// Una armeria a la que el usuario tiene acceso (una de sus membresias).
class TenantOption {
  const TenantOption({
    required this.id,
    required this.nombre,
    required this.slug,
    required this.rol,
  });

  final String id;
  final String nombre;
  final String slug;
  final String rol;
}

/// Destino elegido despues del login (a donde entra el usuario).
enum WorkspaceView { none, platform, tenant }

/// Maneja la sesion de autenticacion (Supabase Auth) y expone la identidad
/// del tenant a partir de los claims del JWT (tenant_id, rol, super admin).
class TenantSessionService extends ChangeNotifier {
  StreamSubscription<AuthState>? _sub;

  String? _tenantId;
  String _appRole = '';
  bool _isPlatformAdmin = false;
  String _email = '';
  bool _busy = false;
  String? _error;

  List<TenantOption> _memberships = const [];
  bool _membershipsLoaded = false;
  WorkspaceView _view = WorkspaceView.none;
  bool _provisioning = false;
  bool _loadingMemberships = false;
  bool _awaitingOrgRegistrationLocal = false;

  bool get isConfigured => AppConfig.useSupabase;

  bool get requiresLogin => isConfigured && !isSignedIn;

  bool get isSignedIn =>
      isConfigured && SupabaseService.client.auth.currentSession != null;

  String? get tenantId => _tenantId;
  String get appRole => _appRole;
  bool get isPlatformAdmin => _isPlatformAdmin;
  String get email => _email;
  bool get busy => _busy;
  String? get error => _error;

  List<TenantOption> get memberships => _memberships;
  bool get membershipsLoaded => _membershipsLoaded;
  WorkspaceView get view => _view;
  bool get provisioning => _provisioning;

  bool get isEmailConfirmed {
    if (!isSignedIn) return false;
    final user = SupabaseService.client.auth.currentUser;
    return user?.emailConfirmedAt != null;
  }

  /// Tras registrar org sin sesion inmediata (confirmacion de email pendiente).
  bool get awaitingEmailConfirmation =>
      isConfigured && !isSignedIn && _awaitingOrgRegistrationLocal;

  /// Sin memberships ni panel de plataforma: cuenta autenticada sin acceso.
  bool get hasNoOrganizationAccess => computeHasNoOrganizationAccess(
        membershipsLoaded: _membershipsLoaded,
        membershipCount: _memberships.length,
        isPlatformAdmin: _isPlatformAdmin,
        isTenantViewNone: _view == WorkspaceView.none,
      );

  int get destinationCount => _memberships.length + (_isPlatformAdmin ? 1 : 0);

  bool get needsWorkspaceChoice =>
      _view == WorkspaceView.none && destinationCount > 1;

  bool get hasCreateOrganizationIntent =>
      RegistrationIntent.hasCreateOrganizationIntent(_userMetadata());

  void start() {
    if (!isConfigured) return;
    _readClaims();
    unawaited(_loadAwaitingOrgFlag().then((_) => notifyListeners()));
    _sub = SupabaseService.client.auth.onAuthStateChange.listen((state) {
      _readClaims();
      if (state.event == AuthChangeEvent.signedOut) {
        _memberships = const [];
        _membershipsLoaded = false;
        _view = WorkspaceView.none;
        _awaitingOrgRegistrationLocal = false;
        _clearAwaitingOrgFlag();
      }
      if (state.event == AuthChangeEvent.signedIn) {
        _membershipsLoaded = false;
        _view = WorkspaceView.none;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Map<String, dynamic>? _userMetadata() {
    return SupabaseService.client.auth.currentUser?.userMetadata;
  }

  Future<void> _loadAwaitingOrgFlag() async {
    final prefs = await SharedPreferences.getInstance();
    _awaitingOrgRegistrationLocal =
        prefs.getBool(RegistrationIntent.prefsAwaitingOrgKey) ?? false;
  }

  Future<void> _setAwaitingOrgFlag(bool value) async {
    _awaitingOrgRegistrationLocal = value;
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      await prefs.setBool(RegistrationIntent.prefsAwaitingOrgKey, true);
    } else {
      await prefs.remove(RegistrationIntent.prefsAwaitingOrgKey);
    }
    notifyListeners();
  }

  Future<void> _clearAwaitingOrgFlag() async {
    _awaitingOrgRegistrationLocal = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(RegistrationIntent.prefsAwaitingOrgKey);
  }

  void _readClaims() {
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) {
      _tenantId = null;
      _appRole = '';
      _isPlatformAdmin = false;
      _email = '';
      return;
    }
    _email = session.user.email ?? '';
    final claims = decodeJwtPayload(session.accessToken);
    _tenantId = (claims['tenant_id'] as String?)?.trim();
    _appRole = (claims['app_role'] as String?)?.trim() ?? '';
    final platform = claims['is_platform_admin'];
    _isPlatformAdmin = platform == true || platform == 'true';
  }

  /// Refresca el JWT y activa el tenant si hace falta (escrituras RLS en Supabase).
  Future<void> ensureSupabaseWriteContext() async {
    if (!isConfigured || !isSignedIn) {
      throw StateError('No hay sesión activa. Volvé a iniciar sesión.');
    }
    if (!_membershipsLoaded) {
      await loadMemberships(force: true);
    }

    await SupabaseService.client.auth.refreshSession();
    _readClaims();
    if (_hasSupabaseWriteContext) return;

    final activeRaw =
        SupabaseService.client.auth.currentUser?.appMetadata['active_tenant'];
    final active = (activeRaw is String ? activeRaw : activeRaw?.toString())
        ?.trim();
    if (active != null && active.isNotEmpty) {
      if (await enterTenant(active) && _hasSupabaseWriteContext) return;
    }

    if (_view == WorkspaceView.tenant && _memberships.isNotEmpty) {
      if (await enterTenant(_memberships.first.id) && _hasSupabaseWriteContext) {
        return;
      }
    }

    if (_memberships.length == 1) {
      if (await enterTenant(_memberships.first.id) && _hasSupabaseWriteContext) {
        return;
      }
    }

    throw StateError(
      'No hay armería activa en la sesión. '
      'Volvé al selector y elegí una organización antes de importar.',
    );
  }

  bool get _hasSupabaseWriteContext =>
      _isPlatformAdmin || (_tenantId != null && _tenantId!.isNotEmpty);

  /// Inicio de sesion con cuenta personal. Nunca crea una organizacion.
  Future<bool> signIn(String email, String password) async {
    if (!isConfigured) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await SupabaseService.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      await SupabaseService.client.auth.refreshSession();
      await _clearAwaitingOrgFlag();
      _view = WorkspaceView.none;
      _membershipsLoaded = false;
      _readClaims();
      _busy = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _busy = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  /// Registro exclusivo del flujo "Registrar mi armeria".
  Future<bool> signUpForOrganization({
    required String email,
    required String password,
    required String companyName,
    required String fullName,
  }) async {
    if (!isConfigured) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final trimmedCompany = companyName.trim();
      final trimmedName = fullName.trim();
      final response = await SupabaseService.client.auth.signUp(
        email: email.trim(),
        password: password,
        data: RegistrationIntent.signUpMetadata(
          companyName: trimmedCompany,
          fullName: trimmedName,
        ),
      );

      if (response.session != null) {
        await _clearAwaitingOrgFlag();
        await SupabaseService.client.auth.refreshSession();
        final provisioned = await provisionOrganization(
          companyName: trimmedCompany,
        );
        if (!provisioned) {
          _busy = false;
          notifyListeners();
          return false;
        }
        _view = WorkspaceView.none;
        _membershipsLoaded = false;
        _readClaims();
      } else {
        await _setAwaitingOrgFlag(true);
      }

      _busy = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _busy = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  void clearPendingRegistration() {
    unawaited(_clearAwaitingOrgFlag());
    notifyListeners();
  }

  /// Usuario ya autenticado sin armería: marca intención y provisiona.
  Future<bool> createOrganizationForCurrentUser({
    required String companyName,
    required String fullName,
  }) async {
    if (!isConfigured || !isSignedIn || !isEmailConfirmed) return false;
    if (_memberships.isNotEmpty) return true;

    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await SupabaseService.client.auth.updateUser(
        UserAttributes(
          data: RegistrationIntent.signUpMetadata(
            companyName: companyName,
            fullName: fullName,
          ),
        ),
      );
      await SupabaseService.client.auth.refreshSession();
      _readClaims();
      final ok = await provisionOrganization(companyName: companyName);
      if (ok) {
        _membershipsLoaded = false;
        await loadMemberships(force: true);
      }
      _busy = false;
      notifyListeners();
      return ok;
    } on AuthException catch (e) {
      _error = e.message;
      _busy = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  /// Crea tenant + membership owner. Solo desde flujo de registro de org.
  Future<bool> provisionOrganization({String? companyName}) async {
    if (!isConfigured || !isSignedIn || !isEmailConfirmed) return false;
    if (!hasCreateOrganizationIntent) return false;
    if (_memberships.isNotEmpty) return true;

    _provisioning = true;
    _error = null;
    notifyListeners();
    try {
      final params = <String, dynamic>{};
      final name = (companyName ?? '').trim();
      final fromMeta = RegistrationIntent.companyNameFrom(_userMetadata()) ?? '';
      final resolved = name.isNotEmpty ? name : fromMeta;
      if (resolved.isNotEmpty) params['p_nombre'] = resolved;

      await SupabaseService.client.rpc('provision_my_tenant', params: params);
      await SupabaseService.client.auth.refreshSession();
      await _clearAwaitingOrgFlag();
      _readClaims();
      _provisioning = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _provisioning = false;
      notifyListeners();
      return false;
    }
  }

  /// Tras login: carga memberships y provisiona solo si hay intencion de registro.
  Future<void> bootstrapSession() async {
    if (!isConfigured || !isSignedIn || !isEmailConfirmed) return;

    await loadMemberships(force: true);

    if (shouldProvisionOrganization(
      hasCreateOrganizationIntent: hasCreateOrganizationIntent,
      activeMembershipCount: _memberships.length,
    )) {
      final ok = await provisionOrganization();
      if (ok) {
        await loadMemberships(force: true);
      }
    }
  }

  Future<void> loadMemberships({bool force = false}) async {
    if (!isConfigured || !isSignedIn) return;
    if (_loadingMemberships) return;
    if (_membershipsLoaded && !force) return;

    _loadingMemberships = true;
    _error = null;
    try {
      final uid = SupabaseService.client.auth.currentUser?.id;
      if (uid == null) {
        _membershipsLoaded = true;
        notifyListeners();
        return;
      }

      final rows = await SupabaseService.client
          .from('memberships')
          .select('tenant_id, rol, tenants(nombre, slug)')
          .eq('user_id', uid)
          .eq('activo', true);

      final list = <TenantOption>[];
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final tenant = map['tenants'] as Map<String, dynamic>?;
        list.add(
          TenantOption(
            id: map['tenant_id'] as String,
            nombre: (tenant?['nombre'] as String?)?.trim().isNotEmpty == true
                ? tenant!['nombre'] as String
                : 'Armería',
            slug: (tenant?['slug'] as String?) ?? '',
            rol: (map['rol'] as String?) ?? 'admin',
          ),
        );
      }
      _memberships = list;

      await _syncPlatformAdminFromServer();

      _membershipsLoaded = true;

      if (_view == WorkspaceView.none && destinationCount == 1) {
        if (_isPlatformAdmin) {
          _view = WorkspaceView.platform;
        } else if (_memberships.length == 1) {
          await enterTenant(_memberships.first.id);
          return;
        }
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _membershipsLoaded = true;
      notifyListeners();
    } finally {
      _loadingMemberships = false;
    }
  }

  Future<void> _syncPlatformAdminFromServer() async {
    if (_isPlatformAdmin) return;
    try {
      final result = await SupabaseService.client.rpc('am_i_platform_admin');
      _isPlatformAdmin = result == true;
    } catch (e, s) {
      AppLogger.warn('am_i_platform_admin falló; uso el claim del JWT',
          error: e, stackTrace: s);
    }
  }

  void enterPlatform() {
    _view = WorkspaceView.platform;
    notifyListeners();
  }

  Future<bool> enterTenant(String tenantId) async {
    if (!isConfigured || !isSignedIn) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await SupabaseService.client.rpc(
        'set_active_tenant',
        params: {'p_tenant': tenantId},
      );
      await SupabaseService.client.auth.refreshSession();
      _readClaims();
      _view = WorkspaceView.tenant;
      _busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  void backToSelector() {
    _view = WorkspaceView.none;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (!isConfigured) return;
    try {
      await SupabaseService.client.auth.signOut();
    } catch (e, s) {
      AppLogger.warn('signOut remoto falló; limpio estado local',
          error: e, stackTrace: s);
    }
    _memberships = const [];
    _membershipsLoaded = false;
    _view = WorkspaceView.none;
    await _clearAwaitingOrgFlag();
    _readClaims();
    notifyListeners();
  }
}
