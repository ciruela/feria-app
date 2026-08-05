import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/admin_service.dart';
import '../../services/catalog_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/seller_service.dart';
import '../../services/tenant_session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/tenant_slug.dart';

/// Recarga datos del tenant activo tras autenticación.
Future<void> reloadTenantData(BuildContext context) async {
  final tenantId = context.read<TenantSessionService>().effectiveTenantId;
  context.read<CatalogService>().bindTenant(tenantId);
  context.read<SellerService>().bindTenant(tenantId);

  await Future.wait([
    context.read<CatalogService>().load(),
    context.read<SellerService>().load(),
    context.read<AdminService>().load(),
    context.read<ExchangeRateService>().load(),
  ]);
}

/// Subtítulo del header según el tipo de entrada (plataforma vs tenant).
String authLandingSubtitle() {
  if (isTenantSubdomainEntry()) {
    return 'Acceso para el equipo de esta armería';
  }
  return 'Panel de administración y ventas';
}

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, this.subtitle});

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TenantSessionService>();
    final slug = detectTenantSlug();
    final title = session.isSignedIn && session.effectiveTenantId != null
        ? session.activeTenantDisplayName
        : slug != null && slug.isNotEmpty
            ? humanizeTenantSlug(slug)
            : 'Feria Armerías';

    return Column(
      children: [
        const Icon(
          Icons.storefront_rounded,
          size: 56,
          color: AppColors.goldDark,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle ?? authLandingSubtitle(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Layout compartido de formularios de autenticación.
class AuthFormShell extends StatelessWidget {
  const AuthFormShell({
    super.key,
    required this.formKey,
    required this.children,
  });

  final GlobalKey<FormState> formKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? validateAuthEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Ingresá tu email';
  if (!v.contains('@')) return 'Email inválido';
  return null;
}

class AuthEmailField extends StatelessWidget {
  const AuthEmailField({
    super.key,
    required this.controller,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: textInputAction,
      decoration: const InputDecoration(
        labelText: 'Email',
        prefixIcon: Icon(Icons.alternate_email_rounded),
      ),
      validator: validateAuthEmail,
    );
  }
}

class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    this.label = 'Contraseña',
    this.textInputAction = TextInputAction.done,
    this.onFieldSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      autofillHints: const [AutofillHints.password],
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
          ),
        ),
      ),
      validator: widget.validator ??
          (value) {
            if ((value ?? '').isEmpty) return 'Ingresá tu contraseña';
            return null;
          },
    );
  }
}

class AuthBusyButton extends StatelessWidget {
  const AuthBusyButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
    required this.backgroundColor,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: busy
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
    );
  }
}
