import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/seller.dart';
import '../services/seller_service.dart';
import '../theme/app_theme.dart';
import '../widgets/feria_shell.dart';
import '../widgets/section_header.dart';
import 'employee/employee_home_screen.dart';

class SellerSelectScreen extends StatelessWidget {
  const SellerSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sellers = context.watch<SellerService>().sellers;

    return FeriaScaffold(
      appBar: const FeriaAppBar(
        title: Text('¿Quién atiende?'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: SectionHeader(
                title: 'Elegí tu nombre',
                subtitle: '${sellers.length} vendedores activos',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.35,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _SellerTile(seller: sellers[index]),
                childCount: sellers.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerTile extends StatelessWidget {
  const _SellerTile({required this.seller});

  final Seller seller;

  String get _initials {
    final parts = seller.nombre.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return seller.nombre.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await context.read<SellerService>().selectSeller(seller);
          if (!context.mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const EmployeeHomeScreen()),
          );
        },
        borderRadius: AppDecorations.radiusLg,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppDecorations.radiusLg,
            border: Border.all(color: AppColors.border),
            boxShadow: [AppDecorations.softShadow],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppDecorations.accentGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  seller.nombre,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
