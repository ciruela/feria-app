import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/tenant_session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/feria_shell.dart';
import 'auth_common.dart';
import 'register_credentials_fields.dart';

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
    final session = context.watch<TenantSessionService>();

    return FeriaScaffold(
      appBar: const FeriaAppBar(title: Text('Crear cuenta')),
      body: AuthFormShell(
        formKey: _formKey,
        children: [
          const AuthHeader(
            subtitle:
                'Creá tu cuenta para que te inviten a una armería existente',
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
            'Después de confirmar el email, pedile al dueño de la armería '
            'que te invite con el mismo correo.',
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
