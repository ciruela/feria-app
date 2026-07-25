import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/uppercase_input.dart';
import '../../widgets/calibre_field.dart';
import '../../widgets/feria_shell.dart';

class AdminProductCreateScreen extends StatefulWidget {
  const AdminProductCreateScreen({super.key});

  @override
  State<AdminProductCreateScreen> createState() =>
      _AdminProductCreateScreenState();
}

class _AdminProductCreateScreenState extends State<AdminProductCreateScreen> {
  ProductType _type = ProductType.municion;
  final _marcaController = TextEditingController();
  final _calibreController = TextEditingController();
  final _modeloController = TextEditingController();
  final _codigoController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _precioController = TextEditingController();
  final _stockController = TextEditingController(text: '1');
  final _roundsPerBoxController = TextEditingController();
  bool _saving = false;

  bool get _isArma =>
      _type == ProductType.armaCorta || _type == ProductType.armaLarga;

  bool get _isMunicion => _type == ProductType.municion;

  @override
  void dispose() {
    _marcaController.dispose();
    _calibreController.dispose();
    _modeloController.dispose();
    _codigoController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    _stockController.dispose();
    _roundsPerBoxController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final precio = double.tryParse(
      _precioController.text.replaceAll(',', '.'),
    );
    if (precio == null || precio < 0) {
      _showError('Precio USD inválido');
      return;
    }

    int? stock;
    if (_stockController.text.trim().isNotEmpty) {
      stock = int.tryParse(_stockController.text.trim());
      if (stock == null || stock < 0) {
        _showError('Stock inválido');
        return;
      }
    }

    int? roundsPerBox;
    if (_isMunicion) {
      roundsPerBox = int.tryParse(_roundsPerBoxController.text.trim());
      if (roundsPerBox == null || roundsPerBox <= 0) {
        _showError('Completá las balas por caja');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await context.read<CatalogService>().addProduct(
            type: _type,
            marca: _marcaController.text,
            calibre: _calibreController.text,
            codigo: _codigoController.text,
            modelo: _modeloController.text,
            descripcion: _descripcionController.text,
            precioUsd: precio,
            stock: stock,
            roundsPerBox: roundsPerBox,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto creado')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      _showError('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildMunicionPreview() {
    final cajas = int.tryParse(_stockController.text.trim());
    final rpb = int.tryParse(_roundsPerBoxController.text.trim());
    if (cajas == null || rpb == null || cajas < 0 || rpb <= 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '$cajas cajas × $rpb balas = ${cajas * rpb} balas totales',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogService>();
    final marca = _marcaController.text.trim();
    final calibers = catalog.calibersFor(
      _type,
      marca.isEmpty ? null : marca,
    );

    return FeriaScaffold(
      appBar: const FeriaAppBar(title: Text('Nuevo producto')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Cargá stock al toque. Se sincroniza en segundos con todos los vendedores.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ProductType.values.map((type) {
              final selected = _type == type;
              return FilterChip(
                label: Text(type.label),
                selected: selected,
                onSelected: _saving
                    ? null
                    : (_) => setState(() {
                          _type = type;
                          _calibreController.clear();
                        }),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _marcaController,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: UpperCaseTextFormatter.formatters,
            enabled: !_saving,
            onChanged: (_) => setState(() => _calibreController.clear()),
            decoration: const InputDecoration(
              labelText: 'Marca',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          CalibreField(
            controller: _calibreController,
            calibers: calibers,
            enabled: !_saving,
          ),
          const SizedBox(height: 12),
          if (_isArma) ...[
            TextField(
              controller: _modeloController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: UpperCaseTextFormatter.formatters,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Modelo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codigoController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: UpperCaseTextFormatter.formatters,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Ref. interna',
                border: OutlineInputBorder(),
              ),
            ),
          ] else
            TextField(
              controller: _codigoController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: UpperCaseTextFormatter.formatters,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Código',
                border: OutlineInputBorder(),
              ),
            ),
          if (_isMunicion) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _descripcionController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: UpperCaseTextFormatter.formatters,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Ej: C.22 LR VARMINT V-MAX 30GR',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _precioController,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _isMunicion ? 'Precio USD (por caja)' : 'Precio USD',
              border: const OutlineInputBorder(),
            ),
          ),
          if (_isMunicion) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _roundsPerBoxController,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Balas por caja',
                hintText: 'Ej: 50',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _stockController,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _isMunicion ? 'Cajas iniciales' : 'Stock inicial',
              hintText: _isMunicion ? 'Ej: 16' : 'Ej: 10',
              border: const OutlineInputBorder(),
            ),
          ),
          if (_isMunicion) _buildMunicionPreview(),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('CREAR PRODUCTO'),
          ),
        ],
      ),
    );
  }
}
