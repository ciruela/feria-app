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

    await reloadTenantData(context);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
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
        ],
      ),
    );
  }
}
