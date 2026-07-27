import 'package:flutter/material.dart';

import 'auth_common.dart';

/// Campos de cuenta para el registro de organización (usuario no autenticado).
class RegisterCredentialsFields extends StatelessWidget {
  const RegisterCredentialsFields({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.confirmController,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthEmailField(controller: emailController),
        const SizedBox(height: 14),
        AuthPasswordField(
          controller: passwordController,
          textInputAction: TextInputAction.next,
          validator: (value) {
            if ((value ?? '').length < 6) return 'Mínimo 6 caracteres';
            return null;
          },
        ),
        const SizedBox(height: 14),
        AuthPasswordField(
          controller: confirmController,
          label: 'Repetir contraseña',
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => onSubmit(),
          validator: (value) {
            if (value != passwordController.text) {
              return 'Las contraseñas no coinciden';
            }
            return null;
          },
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}
