import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';

class AdminChangePinScreen extends StatefulWidget {
  const AdminChangePinScreen({super.key});

  @override
  State<AdminChangePinScreen> createState() => _AdminChangePinScreenState();
}

class _AdminChangePinScreenState extends State<AdminChangePinScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cambiar PIN'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nuevo PIN de administración',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Mínimo 4 dígitos. Compartilo solo con encargados.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nuevo PIN',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Confirmar PIN',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final pin = _pinController.text.trim();
                final confirm = _confirmController.text.trim();

                if (pin.length < 4) {
                  _error(context, 'El PIN debe tener al menos 4 dígitos');
                  return;
                }

                if (pin != confirm) {
                  _error(context, 'Los PIN no coinciden');
                  return;
                }

                await context.read<AuthService>().changeAdminPin(pin);

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN actualizado')),
                );
                Navigator.of(context).pop();
              },
              child: const Text('GUARDAR PIN'),
            ),
          ],
        ),
      ),
    );
  }

  void _error(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
