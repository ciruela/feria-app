import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/tenant_session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/feria_shell.dart';
import 'auth_common.dart';

/// Pantalla para que la persona defina su contraseña.
///
/// Se muestra cuando entra desde el link de invitación por email
/// (metadata `needs_password`) o desde el link de recuperación
/// ("¿Olvidaste tu contraseña?"). Al guardar, [AuthGate] la deja pasar
/// automáticamente a su armería.
class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final session = context.read<TenantSessionService>();
    final ok = await session.setPassword(_passwordController.text);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(session.error ?? 'No se pudo guardar la contraseña'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contraseña guardada. ¡Bienvenido/a!')),
    );
    // AuthGate reacciona a needsPasswordSetup == false y redirige solo.
  }

  Future<void> _cancel() async {
    await context.read<TenantSessionService>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TenantSessionService>();
    final email = session.email;

    return FeriaScaffold(
      appBar: const FeriaAppBar(title: Text('Definí tu contraseña')),
      body: AuthFormShell(
        formKey: _formKey,
        children: [
          const AuthHeader(
            subtitle:
                'Elegí una contraseña para tu cuenta. La vas a usar para '
                'entrar la próxima vez.',
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline_rounded,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          AuthPasswordField(
            controller: _passwordController,
            label: 'Nueva contraseña',
            textInputAction: TextInputAction.next,
            validator: (value) {
              if ((value ?? '').length < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          ),
          const SizedBox(height: 14),
          AuthPasswordField(
            controller: _confirmController,
            label: 'Repetir contraseña',
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          AuthBusyButton(
            label: 'GUARDAR CONTRASEÑA',
            busy: session.busy,
            onPressed: _submit,
            backgroundColor: AppColors.accent,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: session.busy ? null : _cancel,
            child: const Text('Cancelar y salir'),
          ),
        ],
      ),
    );
  }
}
