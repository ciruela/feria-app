import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/registration_intent.dart';
import '../auth/tenant_url_binding.dart';
import '../auth/workspace_resolution.dart';
import '../config/app_config.dart';
import '../models/seller.dart';
import '../utils/app_logger.dart';
import '../utils/jwt.dart';
import '../utils/tenant_slug.dart';
import 'seller_portal_service.dart';
import 'supabase_service.dart';
import 'tenant_subdomain_service.dart';

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
  String? _selectedTenantId;
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
  bool _sessionReady = false;
  bool _bootstrapping = false;
  bool _preferWorkspaceSelector = false;
  String? _sellerId;
  String _sellerNombre = '';
  String _activeTenantNombre = '';
  String _activeTenantSlug = '';

  bool get isConfigured => AppConfig.useSupabase;

  bool get requiresLogin => isConfigured && !isSignedIn;

  bool get isSignedIn =>
      isConfigured && SupabaseService.client.auth.currentSession != null;

  String? get tenantId => _tenantId;

  /// Tenant activo: claim del JWT o el elegido en el selector (fallback).
  String? get effectiveTenantId {
    final claim = _tenantId?.trim();
    if (claim != null && claim.isNotEmpty) return claim;
    final selected = _selectedTenantId?.trim();
    if (selected != null && selected.isNotEmpty) return selected;
    return null;
  }

  String get appRole => _appRole;
  bool get isPlatformAdmin => _isPlatformAdmin;
  String get email => _email;
  String? get sellerId => _sellerId;
  String get sellerNombre => _sellerNombre;
  bool get isAnonymous {
    if (!isConfigured) return false;
    return SupabaseService.client.auth.currentUser?.isAnonymous ?? false;
  }

  /// Vendedor que entró por dominio + clave (sin cuenta email).
  bool get isSellerPortalSession =>
      isSignedIn && _appRole == 'seller' && effectiveTenantId != null;

  bool get busy => _busy;
  String? get error => _error;

  List<TenantOption> get memberships => _memberships;
  bool get membershipsLoaded => _membershipsLoaded;
  WorkspaceView get view => _view;
  bool get provisioning => _provisioning;
  bool get sessionReady => _sessionReady;
  bool get bootstrapping => _bootstrapping;

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
        isPlatformAdmin: canAccessPlatformAdmin,
        isTenantViewNone: _view == WorkspaceView.none,
      );

  /// Panel de plataforma solo en app.armenext.com, no en subdominios tenant.
  bool get canAccessPlatformAdmin =>
      platformAdminVisibleOnEntry(isPlatformAdmin: _isPlatformAdmin);

  int get destinationCount => computeDestinationCount(
        membershipCount: _memberships.length,
        isPlatformAdmin: canAccessPlatformAdmin,
      );

  /// Membresía de la armería activa (JWT / selector).
  TenantOption? get activeMembership {
    final tenantId = effectiveTenantId;
    if (tenantId == null) return null;
    for (final membership in _memberships) {
      if (membership.id == tenantId) return membership;
    }
    return null;
  }

  /// Nombre visible de la armería activa (p. ej. World Guns).
  String get activeTenantDisplayName {
    final membership = activeMembership;
    if (membership != null && membership.nombre.trim().isNotEmpty) {
      return membership.nombre.trim();
    }

    if (_activeTenantNombre.trim().isNotEmpty) {
      return _activeTenantNombre.trim();
    }

    final slug = activeTenantSlug;
    if (slug != null && slug.isNotEmpty) {
      return humanizeTenantSlug(slug);
    }

    return 'Feria Armerías';
  }

  String? get activeTenantSlug {
    final membership = activeMembership;
    if (membership != null && membership.slug.trim().isNotEmpty) {
      return membership.slug.trim();
    }

    if (_activeTenantSlug.trim().isNotEmpty) {
      return _activeTenantSlug.trim();
    }

    if (isSignedIn) {
      final meta = SupabaseService.client.auth.currentUser?.appMetadata;
      final sellerSlug = meta?['seller_slug']?.toString().trim();
      if (sellerSlug != null && sellerSlug.isNotEmpty) return sellerSlug;
    }

    return detectTenantSlug();
  }

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
        _resetWorkspaceState();
        _awaitingOrgRegistrationLocal = false;
        _clearAwaitingOrgFlag();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _resetWorkspaceState() {
    _memberships = const [];
    _membershipsLoaded = false;
    _view = WorkspaceView.none;
    _selectedTenantId = null;
    _sessionReady = false;
    _preferWorkspaceSelector = false;
    _activeTenantNombre = '';
    _activeTenantSlug = '';
  }

  void _syncActiveTenantBranding(String tenantId) {
    for (final membership in _memberships) {
      if (membership.id == tenantId) {
        _activeTenantNombre = membership.nombre;
        _activeTenantSlug = membership.slug;
        return;
      }
    }
    _activeTenantNombre = '';
    _activeTenantSlug = '';
  }

  void _setActiveTenantBranding({
    required String nombre,
    String slug = '',
  }) {
    _activeTenantNombre = nombre.trim();
    _activeTenantSlug = slug.trim();
  }

  bool get needsSessionBootstrap =>
      isSignedIn &&
      isEmailConfirmed &&
      !isSellerPortalSession &&
      !_sessionReady;

  Future<void> ensureSessionReady() async {
    if (!needsSessionBootstrap || _bootstrapping) return;
    _bootstrapping = true;
    notifyListeners();
    try {
      await bootstrapSession();
    } catch (e, s) {
      AppLogger.error('Bootstrap de sesión falló', error: e, stackTrace: s);
      _error = e.toString();
    } finally {
      _sessionReady = true;
      _bootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> _applyWorkspaceResolution() async {
    final resolution = resolveWorkspace(
      currentView: _view,
      jwtTenantId: _tenantId,
      membershipIds: _memberships.map((m) => m.id).toList(),
      isPlatformAdmin: canAccessPlatformAdmin,
      allowJwtAutoSelect: !_preferWorkspaceSelector,
    );

    if (resolution.autoEnterTenantId != null) {
      await enterTenant(resolution.autoEnterTenantId!);
      return;
    }

    if (resolution.syncActiveTenant &&
        resolution.tenantId != null &&
        resolution.tenantId!.isNotEmpty) {
      await enterTenant(resolution.tenantId!);
      return;
    }

    _view = resolution.view;
    _selectedTenantId = resolution.tenantId;
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
      _sellerId = null;
      _sellerNombre = '';
      return;
    }
    _email = session.user.email ?? '';
    final claims = decodeJwtPayload(session.accessToken);
    _tenantId = (claims['tenant_id'] as String?)?.trim();
    _appRole = (claims['app_role'] as String?)?.trim() ?? '';
    _sellerId = (claims['seller_id'] as String?)?.trim();
    _sellerNombre = (claims['seller_nombre'] as String?)?.trim() ?? '';
    final platform = claims['is_platform_admin'];
    _isPlatformAdmin = platform == true || platform == 'true';
  }

  /// Refresca el JWT y activa el tenant si hace falta (escrituras RLS en Supabase).
  Future<void> ensureSupabaseWriteContext() async {
    if (!isConfigured || !isSignedIn) {
      throw StateError('No hay sesión activa. Volvé a iniciar sesión.');
    }
    await SupabaseService.client.auth.refreshSession();
    _readClaims();
    if (isSellerPortalSession && _hasSupabaseWriteContext) return;
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

    final session = SupabaseService.client.auth.currentSession;
    final claims =
        session == null ? const {} : decodeJwtPayload(session.accessToken);
    throw StateError(
      'No hay armería activa en la sesión. '
      'El token de Supabase no trae tenant_id (revisar el hook de Auth). '
      'Diag: tenant_id=${claims['tenant_id'] ?? '∅'} · '
      'is_platform_admin=${claims['is_platform_admin'] ?? '∅'} · '
      'app_role=${claims['app_role'] ?? '∅'} · '
      'memberships=${_memberships.length} · active_tenant=${active ?? '∅'}',
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
      _selectedTenantId = null;
      _membershipsLoaded = false;
      _sessionReady = false;
      _preferWorkspaceSelector = !isTenantSubdomainEntry();
      _readClaims();
      await ensureSessionReady();
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

  /// Crea cuenta personal sin organización (para quienes recibirán una invitación).
  Future<bool> signUpForTeamAccess({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (!isConfigured) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final response = await SupabaseService.client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          RegistrationIntent.fullNameKey: fullName.trim(),
        },
      );

      if (response.session != null) {
        await _clearAwaitingOrgFlag();
        await SupabaseService.client.auth.refreshSession();
        _view = WorkspaceView.none;
        _membershipsLoaded = false;
        _readClaims();
        await ensureSessionReady();
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
      // Best-effort: subdominio tenant.armenext.com en Cloudflare Pages.
      unawaited(TenantSubdomainService().registerForCurrentTenant());
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
      _memberships = _applyUrlTenantBinding(list);

      await _syncPlatformAdminFromServer();

      _membershipsLoaded = true;

      await _applyWorkspaceResolution();
      final activeId = effectiveTenantId;
      if (activeId != null) {
        _syncActiveTenantBranding(activeId);
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
    if (!canAccessPlatformAdmin) return;
    _view = WorkspaceView.platform;
    _preferWorkspaceSelector = false;
    _selectedTenantId = null;
    notifyListeners();
    unawaited(_refreshSessionForPlatformView());
  }

  Future<void> _refreshSessionForPlatformView() async {
    if (!isConfigured || !isSignedIn) return;
    try {
      await SupabaseService.client.auth.refreshSession();
      _readClaims();
      notifyListeners();
    } catch (e, s) {
      AppLogger.warn('refreshSession en panel plataforma falló',
          error: e, stackTrace: s);
    }
  }

  List<TenantOption> _applyUrlTenantBinding(List<TenantOption> loaded) {
    final boundSlug = boundTenantSlugFromEntry();
    if (boundSlug == null) return loaded;
    return filterByBoundTenantSlug(
      items: loaded,
      boundSlug: boundSlug,
      slugOf: (membership) => membership.slug,
    );
  }

  void backToSelector() {
    _selectedTenantId = null;
    _view = WorkspaceView.none;
    _preferWorkspaceSelector = true;
    _sessionReady = true;
    _activeTenantNombre = '';
    _activeTenantSlug = '';
    notifyListeners();
  }

  Future<bool> enterTenant(String tenantId) async {
    if (!isConfigured || !isSignedIn) return false;
    if (!_memberships.any((membership) => membership.id == tenantId)) {
      _error = isTenantSubdomainEntry()
          ? 'Tu cuenta no tiene acceso a esta armería.'
          : 'No tenés acceso a esa armería.';
      notifyListeners();
      return false;
    }
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
      _selectedTenantId = tenantId;
      _syncActiveTenantBranding(tenantId);
      _view = WorkspaceView.tenant;
      _preferWorkspaceSelector = false;
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

  /// Portal vendedor: sesión anónima + JWT con tenant y seller_id.
  Future<void> signInSellerPortal({
    required String slug,
    required String codigo,
    required Seller seller,
    required String tenantId,
    required String tenantNombre,
  }) async {
    if (!isConfigured) {
      throw StateError('Supabase no configurado');
    }

    _busy = true;
    _error = null;
    notifyListeners();

    try {
      await SupabaseService.client.auth.signOut();

      await SupabaseService.client.auth.signInAnonymously();

      final login = await SellerPortalService().completeLogin(
        slug: slug,
        codigo: codigo,
        sellerId: seller.id,
      );

      await SupabaseService.client.auth.refreshSession();
      _readClaims();
      _selectedTenantId = tenantId;
      _setActiveTenantBranding(
        nombre: tenantNombre.trim().isNotEmpty
            ? tenantNombre
            : login.tenantNombre,
        slug: slug.trim(),
      );
      _view = WorkspaceView.tenant;
      _membershipsLoaded = true;
      _memberships = const [];
      _sessionReady = true;
      _busy = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _busy = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!isConfigured) return;
    try {
      await SupabaseService.client.auth.signOut();
    } catch (e, s) {
      AppLogger.warn('signOut remoto falló; limpio estado local',
          error: e, stackTrace: s);
    }
    _resetWorkspaceState();
    await _clearAwaitingOrgFlag();
    _readClaims();
    notifyListeners();
  }
}
