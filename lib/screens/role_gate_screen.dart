import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_role.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/big_action_button.dart';
import 'admin/admin_home_screen.dart';
import 'seller_select_screen.dart';

class RoleGateScreen extends StatelessWidget {
  const RoleGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo Feria'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '¿Cómo entrás?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Empleados ven precios y stock. Administración edita catálogo.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          BigActionButton(
            label: AppRole.employee.label,
            subtitle: 'Consultar precios y stock',
            icon: Icons.storefront_outlined,
            onTap: () => _enterAs(context, AppRole.employee),
          ),
          const SizedBox(height: 16),
          BigActionButton(
            label: AppRole.admin.label,
            subtitle: 'Editar productos, stock y dólar',
            icon: Icons.admin_panel_settings_outlined,
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
      title: const Text('PIN de administración'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'PIN',
            border: OutlineInputBorder(),
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
      color: isAdmin ? AppColors.accent : Colors.white24,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
     role.label.toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    ),
  );
}
