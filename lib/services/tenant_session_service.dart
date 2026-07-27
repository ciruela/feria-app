import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
///
/// Modelo hibrido: los admins/duenos inician sesion con email/contrasena; esta
/// sesion define el tenant. Los vendedores luego se identifican con PIN sobre
/// esta misma sesion (ver AdminService / SellerService).
///
/// Multi-membresia: un usuario puede pertenecer a varias armerias (y/o ser
/// platform admin). Tras el login elige a donde entrar; el tenant activo se
/// persiste en app_metadata via RPC `set_active_tenant` y se regenera el JWT.
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
  bool _provisionChecked = false;
  bool _loadingMemberships = false;
  String? _pendingCompanyName;

  bool get isConfigured => AppConfig.useSupabase;

  /// Si no usamos Supabase (modo local), no hay login: la app entra directo.
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

  /// Tras signUp con confirmacion de email, la sesion puede ser null hasta confirmar.
  bool get awaitingEmailConfirmation =>
      isConfigured && !isSignedIn && _pendingCompanyName != null;

  /// Cantidad de destinos disponibles (armerias + panel de plataforma).
  int get destinationCount => _memberships.length + (_isPlatformAdmin ? 1 : 0);

  /// True si hay que mostrar el selector (mas de un destino y todavia no eligio).
  bool get needsWorkspaceChoice =>
      _view == WorkspaceView.none && destinationCount > 1;

  void start() {
    if (!isConfigured) return;
    _readClaims();
    _sub = SupabaseService.client.auth.onAuthStateChange.listen((state) {
      _readClaims();
      if (state.event == AuthChangeEvent.signedOut) {
        _memberships = const [];
        _membershipsLoaded = false;
        _view = WorkspaceView.none;
        _pendingCompanyName = null;
        _provisionChecked = false;
      }
      if (state.event == AuthChangeEvent.signedIn) {
        _pendingCompanyName = null;
        _provisionChecked = false;
        _membershipsLoaded = false;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
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

  Future<bool> signIn(String email, String password) async {
    if (!isConfigured) return false;
    _busy = true;
    _error = null;
    _pendingCompanyName = null;
    notifyListeners();
    try {
      await SupabaseService.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      await SupabaseService.client.auth.refreshSession();
      _view = WorkspaceView.none;
      _membershipsLoaded = false;
      _provisionChecked = false;
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

  /// Registro: crea usuario en Auth con metadata de empresa. Supabase envia email
  /// de confirmacion; el tenant se provisiona al primer login confirmado.
  Future<bool> signUp({
    required String email,
    required String password,
    required String companyName,
  }) async {
    if (!isConfigured) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final trimmedCompany = companyName.trim();
      final response = await SupabaseService.client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'company_name': trimmedCompany},
      );

      if (response.session != null) {
        // Confirmacion de email deshabilitada en el proyecto: provisionar ya.
        _pendingCompanyName = null;
        await SupabaseService.client.auth.refreshSession();
        await provisionTenantIfNeeded(companyName: trimmedCompany);
        _view = WorkspaceView.none;
        _membershipsLoaded = false;
        _readClaims();
      } else {
        _pendingCompanyName = trimmedCompany;
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
    _pendingCompanyName = null;
    notifyListeners();
  }

  /// Crea tenant + membership si el usuario confirmo email y aun no tiene armeria.
  Future<bool> provisionTenantIfNeeded({String? companyName}) async {
    if (!isConfigured || !isSignedIn || !isEmailConfirmed) return false;
    if (_provisionChecked) return true;

    _provisioning = true;
    _error = null;
    notifyListeners();
    try {
      final params = <String, dynamic>{};
      final name = (companyName ?? _pendingCompanyName ?? '').trim();
      if (name.isNotEmpty) params['p_nombre'] = name;

      await SupabaseService.client.rpc('provision_my_tenant', params: params);
      await SupabaseService.client.auth.refreshSession();
      _pendingCompanyName = null;
      _provisionChecked = true;
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

  /// Carga las armerias a las que el usuario tiene acceso (para el selector).
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

      // Auto-seleccion: solo si hay UN destino (solo armeria o solo plataforma).
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
      // Si falla, seguimos con lo que diga el JWT.
      AppLogger.warn('am_i_platform_admin falló; uso el claim del JWT',
          error: e, stackTrace: s);
    }
  }

  /// Entra al panel global de plataforma (super admin).
  void enterPlatform() {
    _view = WorkspaceView.platform;
    notifyListeners();
  }

  /// Cambia el tenant activo: persiste la eleccion en app_metadata (RPC) y
  /// regenera el JWT para que la RLS opere sobre esa armeria.
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

  /// Vuelve al selector de espacio de trabajo (si hay mas de un destino).
  void backToSelector() {
    _view = WorkspaceView.none;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (!isConfigured) return;
    try {
      await SupabaseService.client.auth.signOut();
    } catch (e, s) {
      // Ignorar: igual limpiamos el estado local.
      AppLogger.warn('signOut remoto falló; limpio estado local',
          error: e, stackTrace: s);
    }
    _memberships = const [];
    _membershipsLoaded = false;
    _view = WorkspaceView.none;
    _pendingCompanyName = null;
    _provisionChecked = false;
    _readClaims();
    notifyListeners();
  }
}
