import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/seller.dart';
import '../../models/app_role.dart';
import '../../services/auth_service.dart';
import '../../services/seller_portal_service.dart';
import '../../services/seller_service.dart';
import '../../services/tenant_session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/feria_shell.dart';

/// Acceso de vendedor sin registro: dominio + clave + elegir nombre.
class SellerPortalScreen extends StatefulWidget {
  const SellerPortalScreen({super.key});

  @override
  State<SellerPortalScreen> createState() => _SellerPortalScreenState();
}

class _SellerPortalScreenState extends State<SellerPortalScreen> {
  final _slugController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _portal = SellerPortalService();

  bool _loading = false;
  String? _error;
  SellerPortalValidation? _validation;

  @override
  void dispose() {
    _slugController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _validateAccess() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _portal.validatePortal(
        slug: _slugController.text,
        codigo: _codeController.text,
      );
      if (!mounted) return;
      setState(() {
        _validation = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _enterAsSeller(Seller seller) async {
    final validation = _validation;
    if (validation == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = context.read<TenantSessionService>();
      await session.signInSellerPortal(
        slug: _slugController.text.trim(),
        codigo: _codeController.text.trim(),
        seller: seller,
        tenantId: validation.tenantId,
      );

      if (!mounted) return;
      context.read<AuthService>().loginAs(AppRole.employee);
      context.read<SellerService>().bindTenant(validation.tenantId);
      await context.read<SellerService>().selectSeller(seller);

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _backToCredentials() {
    setState(() {
      _validation = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.useSupabase) {
      return const FeriaScaffold(
        appBar: FeriaAppBar(title: Text('Entrar como vendedor')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'El acceso de vendedores requiere Supabase configurado.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final validation = _validation;

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: Text(
          validation == null ? 'Entrar como vendedor' : '¿Quién sos?',
        ),
        leading: validation == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _loading ? null : _backToCredentials,
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          if (validation == null) ...[
            const Icon(Icons.storefront_rounded,
                size: 56, color: AppColors.accent),
            const SizedBox(height: 16),
            const Text(
              'Acceso rápido para el equipo de ventas',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'No necesitás crear cuenta. Pedile a la armería el dominio '
              'y la clave de vendedores.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 28),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _slugController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Dominio de la armería',
                      hintText: 'ej: world-guns',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.language_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 2) {
                        return 'Ingresá el dominio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _codeController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Clave de vendedores',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 4) {
                        return 'Mínimo 4 caracteres';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _validateAccess(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _validateAccess,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'CONTINUAR',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    validation.tenantNombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    validation.tenantSlug,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Elegí tu nombre',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...validation.sellers.map(
              (seller) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                      child: Text(
                        seller.nombre.isNotEmpty
                            ? seller.nombre[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    title: Text(
                      seller.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _loading ? null : () => _enterAsSeller(seller),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
