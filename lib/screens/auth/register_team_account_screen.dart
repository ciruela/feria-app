import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/tenant_session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/tenant_slug.dart';
import '../../widgets/feria_shell.dart';
import 'auth_common.dart';
import 'register_credentials_fields.dart';
import 'tenant_registration_blocked_screen.dart';

/// Registro de cuenta personal para unirse a una armería existente vía invitación.
class RegisterTeamAccountScreen extends StatefulWidget {
  const RegisterTeamAccountScreen({super.key});

  @override
  State<RegisterTeamAccountScreen> createState() =>
      _RegisterTeamAccountScreenState();
}

class _RegisterTeamAccountScreenState extends State<RegisterTeamAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final session = context.read<TenantSessionService>();
    final ok = await session.signUpForTeamAccess(
      email: _emailController.text,
      password: _passwordController.text,
      fullName: _fullNameController.text,
    );
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(session.error ?? 'No se pudo crear la cuenta')),
      );
      return;
    }

    if (session.isSignedIn) {
      await reloadTenantData(context);
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (isTenantSubdomainEntry()) {
      return const TenantRegistrationBlockedScreen();
    }

    final session = context.watch<TenantSessionService>();

    return FeriaScaffold(
      appBar: const FeriaAppBar(title: Text('Crear cuenta')),
      body: AuthFormShell(
        formKey: _formKey,
        children: [
          const AuthHeader(
            subtitle:
                'Si te invitaron por mail, usá el link del correo. '
                'Si no, creá la cuenta con el mismo email de la invitación.',
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _fullNameController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre y apellido',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) {
              if ((value ?? '').trim().length < 2) return 'Ingresá tu nombre';
              return null;
            },
          ),
          const SizedBox(height: 14),
          RegisterCredentialsFields(
            emailController: _emailController,
            passwordController: _passwordController,
            confirmController: _confirmController,
            onSubmit: _submit,
          ),
          AuthBusyButton(
            label: 'CREAR CUENTA',
            busy: session.busy,
            onPressed: _submit,
            backgroundColor: AppColors.accent,
          ),
          const SizedBox(height: 16),
          const Text(
            'Lo más simple: pedile al dueño que te invite desde Equipo; '
            'te llega un mail para crear la contraseña. Esta pantalla es '
            'por si preferís registrarte vos primero.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
