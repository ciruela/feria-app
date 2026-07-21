import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_role.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/big_action_button.dart';
import '../widgets/feria_shell.dart';
import '../widgets/section_header.dart';
import 'admin/admin_home_screen.dart';
import 'seller_select_screen.dart';

class RoleGateScreen extends StatelessWidget {
  const RoleGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FeriaScaffold(
      appBar: const FeriaAppBar(
        title: Text('Catálogo Feria'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          _HeroHeader(),
          const SizedBox(height: 28),
          const SectionHeader(
            title: '¿Cómo entrás?',
            subtitle: 'Empleados consultan precios. Administración edita catálogo.',
          ),
          const SizedBox(height: 22),
          BigActionButton(
            label: AppRole.employee.label,
            subtitle: 'Consultar precios, stock y carrito',
            icon: Icons.storefront_rounded,
            accentColor: AppColors.accent,
            onTap: () => _enterAs(context, AppRole.employee),
          ),
          const SizedBox(height: 16),
          BigActionButton(
            label: AppRole.admin.label,
            subtitle: 'Editar productos, stock y tipo de cambio',
            icon: Icons.admin_panel_settings_rounded,
            accentColor: AppColors.goldDark,
            onTap: () => _askAdminPin(context),
          ),
        ],
      ),
    );
  }

  void _enterAs(BuildContext context, AppRole role) {
    context.read<AuthService>().loginAs(role);

    final screen = role == AppRole.admin
        ? const AdminHomeScreen()
        : const SellerSelectScreen();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _askAdminPin(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _AdminPinDialog(),
    );

    if (ok == true && context.mounted) {
      _enterAs(context, AppRole.admin);
    }
  }
}

class _HeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppDecorations.cardGradient,
        borderRadius: AppDecorations.radiusLg,
        boxShadow: [AppDecorations.cardShadow],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppDecorations.goldGradient,
              borderRadius: AppDecorations.radiusMd,
            ),
            child: const Icon(
              Icons.local_mall_rounded,
              color: AppColors.primaryDark,
              size: 38,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FERIA ARMAS',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        letterSpacing: 1.4,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Caza · Pesca · Munición',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminPinDialog extends StatefulWidget {
  const _AdminPinDialog();

  @override
  State<_AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<_AdminPinDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return AlertDialog(
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock_rounded, color: AppColors.goldDark, size: 28),
      ),
      title: const Text('PIN de administración'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
          ),
          decoration: const InputDecoration(
            labelText: 'Ingresá el PIN',
            hintText: '••••',
          ),
          validator: (value) {
            if (value == null || !auth.verifyAdminPin(value)) {
              return 'PIN incorrecto';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('CANCELAR'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.goldDark,
          ),
          child: const Text('ENTRAR'),
        ),
      ],
    );
  }
}

void exitToRoleGate(BuildContext context) {
  context.read<AuthService>().logout();
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const RoleGateScreen()),
    (_) => false,
  );
}

Widget roleBadge(AppRole role) {
  final isAdmin = role == AppRole.admin;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      gradient: isAdmin ? AppDecorations.goldGradient : null,
      color: isAdmin ? null : Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isAdmin
            ? AppColors.goldDark.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.25),
      ),
    ),
    child: Text(
      role.label.toUpperCase(),
      style: TextStyle(
        color: isAdmin ? AppColors.primaryDark : Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 11,
        letterSpacing: 0.8,
      ),
    ),
  );
}
