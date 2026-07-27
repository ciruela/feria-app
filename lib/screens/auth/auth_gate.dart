import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/tenant_session_service.dart';
import '../role_gate_screen.dart';
import '../super_admin/super_admin_home_screen.dart';
import 'auth_screen.dart';
import 'email_confirmation_screen.dart';
import 'workspace_selector_screen.dart';

/// Decide la pantalla inicial segun autenticacion, confirmacion de email y tenant.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _bootstrapped = false;
  bool _bootstrapping = false;
  TenantSessionService? _session;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _session ??= context.read<TenantSessionService>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _session?.addListener(_onSessionChanged);
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _session?.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    final session = _session;
    if (session == null) return;
    if (!session.isSignedIn) {
      if (_bootstrapped || _bootstrapping) {
        setState(() {
          _bootstrapped = false;
          _bootstrapping = false;
        });
      }
      return;
    }
    // Bootstrap solo una vez por sesion; evita bucle con refreshSession/provision.
    if (session.isEmailConfirmed && !_bootstrapped && !_bootstrapping) {
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    final session = _session;
    if (session == null ||
        !session.isConfigured ||
        !session.isSignedIn ||
        !session.isEmailConfirmed ||
        _bootstrapping) {
      return;
    }

    _bootstrapping = true;
    await session.provisionTenantIfNeeded();
    if (!mounted) return;
    setState(() {
      _bootstrapped = true;
      _bootstrapping = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TenantSessionService>();

    if (!session.isConfigured) {
      return const RoleGateScreen();
    }

    if (session.awaitingEmailConfirmation) {
      return const EmailConfirmationScreen();
    }

    if (!session.isSignedIn) {
      return const AuthScreen();
    }

    if (!session.isEmailConfirmed) {
      return const EmailConfirmationScreen();
    }

    if (!_bootstrapped || session.provisioning || _bootstrapping) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    switch (session.view) {
      case WorkspaceView.platform:
        return const SuperAdminHomeScreen();
      case WorkspaceView.tenant:
        return const RoleGateScreen();
      case WorkspaceView.none:
        return const WorkspaceSelectorScreen();
    }
  }
}
