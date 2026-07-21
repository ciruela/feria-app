import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/seller.dart';
import '../services/seller_service.dart';
import 'employee/employee_home_screen.dart';

class SellerSelectScreen extends StatelessWidget {
  const SellerSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sellers = context.watch<SellerService>().sellers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('¿Quién atiende?'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
        ),
        itemCount: sellers.length,
        itemBuilder: (context, index) {
          final seller = sellers[index];
          return _SellerTile(seller: seller);
        },
      ),
    );
  }
}

class _SellerTile extends StatelessWidget {
  const _SellerTile({required this.seller});

  final Seller seller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () async {
          await context.read<SellerService>().selectSeller(seller);
          if (!context.mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const EmployeeHomeScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD1D5DB), width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            seller.nombre,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
