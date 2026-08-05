import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/tenant_session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/tenant_slug.dart';
import '../../widgets/feria_shell.dart';
import 'auth_common.dart';
import 'register_credentials_fields.dart';
import 'tenant_registration_blocked_screen.dart';

class RegisterOrganizationScreen extends StatefulWidget {
  const RegisterOrganizationScreen({super.key});

  @override
  State<RegisterOrganizationScreen> createState() =>
      _RegisterOrganizationScreenState();
}

class _RegisterOrganizationScreenState
    extends State<RegisterOrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _companyController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final session = context.read<TenantSessionService>();
    final signedIn = session.isSignedIn;

    final ok = signedIn
        ? await session.createOrganizationForCurrentUser(
            companyName: _companyController.text,
            fullName: _fullNameController.text,
          )
        : await session.signUpForOrganization(
            email: _emailController.text,
            password: _passwordController.text,
            companyName: _companyController.text,
            fullName: _fullNameController.text,
          );
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(session.error ?? 'No se pudo registrar')),
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
    final slugPreview = slugifyTenantName(_companyController.text);
    final signedIn = session.isSignedIn;

    return FeriaScaffold(
      appBar: const FeriaAppBar(title: Text('Registrar mi armería')),
      body: AuthFormShell(
        formKey: _formKey,
        children: [
          AuthHeader(
            subtitle: signedIn
                ? 'Creá tu organización con la cuenta actual'
                : 'Creá tu organización y quedá como dueño',
          ),
          if (signedIn && session.email.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              session.email,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
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
          TextFormField(
            controller: _companyController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Nombre de la armería',
              prefixIcon: const Icon(Icons.store_rounded),
              helperText: _companyController.text.trim().isEmpty
                  ? null
                  : 'Tu URL: ${tenantPortalUrl(slugPreview)}',
            ),
            validator: (value) {
              if ((value ?? '').trim().length < 2) {
                return 'Ingresá el nombre de tu armería';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          if (!signedIn)
            RegisterCredentialsFields(
              emailController: _emailController,
              passwordController: _passwordController,
              confirmController: _confirmController,
              onSubmit: _submit,
            )
          else
            const SizedBox(height: 28),
          AuthBusyButton(
            label: 'CREAR ORGANIZACIÓN',
            busy: session.busy,
            onPressed: _submit,
            backgroundColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}
