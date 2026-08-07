import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/tenant_session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/feria_shell.dart';
import 'auth_common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final session = context.read<TenantSessionService>();
    final ok = await session.signIn(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(session.error ?? 'No se pudo iniciar sesión')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _forgotPassword() async {
    final session = context.read<TenantSessionService>();
    final controller = TextEditingController(text: _emailController.text.trim());

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Te mandamos un mail con un link para elegir una '
              'contraseña nueva.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              onSubmitted: (value) =>
                  Navigator.of(dialogContext).pop(value.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty || !mounted) return;
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email inválido')),
      );
      return;
    }

    final ok = await session.sendPasswordReset(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Listo. Si $email tiene cuenta, le llega el mail para '
                  'cambiar la contraseña.'
              : session.error ?? 'No se pudo enviar el mail',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TenantSessionService>();

    return FeriaScaffold(
      appBar: const FeriaAppBar(title: Text('Iniciar sesión')),
      body: AuthFormShell(
        formKey: _formKey,
        children: [
          const AuthHeader(subtitle: 'Ingresá con tu cuenta personal'),
          const SizedBox(height: 28),
          AuthEmailField(controller: _emailController),
          const SizedBox(height: 14),
          AuthPasswordField(
            controller: _passwordController,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 28),
          AuthBusyButton(
            label: 'INGRESAR',
            busy: session.busy,
            onPressed: _submit,
            backgroundColor: AppColors.goldDark,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: session.busy ? null : _forgotPassword,
            child: const Text('¿Olvidaste tu contraseña?'),
          ),
        ],
      ),
    );
  }
}
