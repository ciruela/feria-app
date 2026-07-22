import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/product.dart';
import '../../services/catalog_service.dart';
import '../../services/product_photo_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/uppercase_input.dart';
import '../../widgets/feria_shell.dart';

class AdminProductEditScreen extends StatefulWidget {
  const AdminProductEditScreen({
    super.key,
    required this.productId,
  });

  final String productId;

  @override
  State<AdminProductEditScreen> createState() => _AdminProductEditScreenState();
}

class _AdminProductEditScreenState extends State<AdminProductEditScreen> {
  late final TextEditingController _precioController;
  late final TextEditingController _stockController;
  late final TextEditingController _modeloController;
  late final TextEditingController _calibreController;
  late final TextEditingController _codigoController;
  final _photos = ProductPhotoService();

  Product? _product;
  bool _uploadingPhoto = false;
  String? _deletingPath;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  void _loadProduct() {
    _product = context.read<CatalogService>().productById(widget.productId);
    _precioController = TextEditingController(
      text: _product?.precioUsd.toString() ?? '',
    );
    _stockController = TextEditingController(
      text: _product?.stock?.toString() ?? '',
    );
    _modeloController = TextEditingController(
      text: _product?.modelo ?? '',
    );
    _calibreController = TextEditingController(
      text: _product?.calibre ?? '',
    );
    _codigoController = TextEditingController(
      text: _product?.codigo ?? '',
    );
  }

  @override
  void dispose() {
    _precioController.dispose();
    _stockController.dispose();
    _modeloController.dispose();
    _calibreController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    if (!AppConfig.useSupabase) {
      _showError('Conectá Supabase para subir fotos a la nube');
      return;
    }

    final product = _product;
    if (product == null) return;

    final file = await _photos.pickPhoto(source);
    if (file == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final updated =
          await context.read<CatalogService>().uploadProductPhoto(product.id, file);
      if (!mounted) return;

      setState(() => _product = updated);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto subida — se sincroniza al equipo')),
      );
    } catch (error) {
      if (!mounted) return;
      _showError('No se pudo subir la foto: $error');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _confirmDeletePhoto(String storagePath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('¿Querés borrar esta foto del producto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'ELIMINAR',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _deletePhoto(storagePath);
  }

  Future<void> _deletePhoto(String storagePath) async {
    final product = _product;
    if (product == null) return;

    setState(() => _deletingPath = storagePath);
    try {
      final updated = await context
          .read<CatalogService>()
          .deleteProductPhoto(product.id, storagePath);
      if (!mounted) return;

      setState(() => _product = updated);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto eliminada')),
      );
    } catch (error) {
      if (!mounted) return;
      _showError('No se pudo eliminar la foto: $error');
    } finally {
      if (mounted) setState(() => _deletingPath = null);
    }
  }

  Future<void> _showPhotoOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Sacar foto'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;

    if (product == null) {
      return const FeriaScaffold(
        appBar: FeriaAppBar(title: Text('Producto')),
        body: Center(child: Text('Producto no encontrado')),
      );
    }

    final folderPath = '${ProductPhotoService.folderFor(product)}/${product.id}/';

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: Text(product.isArma ? product.modeloDisplay : product.codigo),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PhotoSection(
            fotoPaths: product.fotoUrls,
            folderPath: folderPath,
            typeLabel: product.type.label,
            uploading: _uploadingPhoto,
            deletingPath: _deletingPath,
            onUploadTap: _showPhotoOptions,
            onDeleteTap: _confirmDeletePhoto,
          ),
          const SizedBox(height: 20),
          _ReadOnlyField(label: 'Marca', value: product.marca),
          const SizedBox(height: 12),
          if (product.isArma) ...[
            TextField(
              controller: _modeloController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: UpperCaseTextFormatter.formatters,
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
              decoration: const InputDecoration(
                labelText: 'Código',
                border: OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _calibreController,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: UpperCaseTextFormatter.formatters,
            decoration: const InputDecoration(
              labelText: 'Calibre',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _ReadOnlyField(label: 'Tipo', value: product.type.label),
          const SizedBox(height: 24),
          TextField(
            controller: _precioController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio USD',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _stockController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Stock (vacío = no mostrar)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _uploadingPhoto ? null : () => _save(context, product),
            child: const Text('GUARDAR CAMBIOS'),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, Product product) async {
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

    final calibre = _calibreController.text.trim();
    if (calibre.isEmpty) {
      _showError('Completá el calibre');
      return;
    }

    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) {
      _showError(product.isArma
          ? 'Completá la ref. interna'
          : 'Completá el código');
      return;
    }

    final updated = product.copyWith(
      precioUsd: precio,
      stock: stock,
      foto: '',
      modelo: product.isArma ? _modeloController.text.trim() : product.modelo,
      calibre: calibre,
      codigo: codigo,
    );

    await context.read<CatalogService>().updateProduct(updated);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Producto actualizado')),
    );
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.fotoPaths,
    required this.folderPath,
    required this.typeLabel,
    required this.uploading,
    required this.deletingPath,
    required this.onUploadTap,
    required this.onDeleteTap,
  });

  final List<String> fotoPaths;
  final String folderPath;
  final String typeLabel;
  final bool uploading;
  final String? deletingPath;
  final VoidCallback onUploadTap;
  final ValueChanged<String> onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final displayUrls = ProductPhotoService.displayUrls(fotoPaths);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (displayUrls.isEmpty)
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: _PhotoPlaceholder(),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 4 / 3,
              ),
              itemCount: displayUrls.length,
              itemBuilder: (context, index) {
                final storagePath = fotoPaths[index];
                final displayUrl = displayUrls[index];
                final deleting = deletingPath != null &&
                    ProductPhotoService.stripVersion(
                          ProductPhotoService.normalizeForStorage(deletingPath!),
                        ) ==
                        ProductPhotoService.stripVersion(
                          ProductPhotoService.normalizeForStorage(storagePath),
                        );

                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: displayUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const ColoredBox(
                          color: AppColors.surfaceMuted,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (_, __, ___) => const _PhotoPlaceholder(),
                      ),
                      if (deleting)
                        const ColoredBox(
                          color: Color(0x88000000),
                          child: Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        )
                      else
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: uploading ? null : () => onDeleteTap(storagePath),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          Text(
            'Carpeta: $typeLabel',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            folderPath,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: AppColors.textSecondary,
            ),
          ),
          if (fotoPaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${fotoPaths.length} foto${fotoPaths.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: uploading ? null : onUploadTap,
            icon: uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              uploading
                  ? 'SUBIENDO...'
                  : fotoPaths.isEmpty
                      ? 'SACAR / ELEGIR FOTO'
                      : 'AGREGAR OTRA FOTO',
            ),
          ),
          if (!AppConfig.useSupabase) ...[
            const SizedBox(height: 8),
            const Text(
              'Requiere Supabase configurado para sincronizar fotos al equipo.',
              style: TextStyle(fontSize: 12, color: AppColors.goldDark),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceMuted,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textSecondary),
          SizedBox(height: 8),
          Text(
            'Sin fotos',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
