import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/seller.dart';
import '../services/auth_service.dart';
import '../services/in_tenant_flow_service.dart';
import '../services/seller_service.dart';
import '../utils/layout_breakpoints.dart';
import '../widgets/employee/seller_select_desktop.dart';
import '../widgets/employee/seller_select_mobile.dart';
import 'auth/auth_common.dart';

class SellerSelectScreen extends StatefulWidget {
  const SellerSelectScreen({
    super.key,
    required this.onSellerSelected,
  });

  final ValueChanged<Seller> onSellerSelected;

  @override
  State<SellerSelectScreen> createState() => _SellerSelectScreenState();
}

class _SellerSelectScreenState extends State<SellerSelectScreen> {
  Seller? _preselected;
  bool _confirming = false;

  void _goBack(BuildContext context) {
    context.read<AuthService>().logout();
    context.read<InTenantFlowService>().backToRoleGate();
  }

  void _selectSeller(Seller seller) {
    if (_preselected?.id == seller.id) {
      _confirm();
      return;
    }
    setState(() => _preselected = seller);
  }

  Future<void> _confirm() async {
    final seller = _preselected;
    if (seller == null || _confirming) return;

    setState(() => _confirming = true);
    try {
      await context.read<SellerService>().selectSeller(seller);
      if (!mounted) return;
      await loadCartForSeller(context, seller.id);
      if (!mounted) return;
      widget.onSellerSelected(seller);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la selección: $e')),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sellerService = context.watch<SellerService>();
    final sellers = sellerService.sellers;
    final isDesktop =
        LayoutBreakpoints.isDesktop(MediaQuery.sizeOf(context).width);

    final layoutProps = (
      sellers: sellers,
      selected: _preselected,
      confirming: _confirming,
      isSyncing: sellerService.isSyncing,
      lastError: sellerService.lastError,
      onBack: () => _goBack(context),
      onSelect: _selectSeller,
      onContinue: _confirm,
      onRefresh: sellerService.syncFromCloud,
    );

    if (isDesktop) {
      return SellerSelectDesktopLayout(
        sellers: layoutProps.sellers,
        selected: layoutProps.selected,
        confirming: layoutProps.confirming,
        isSyncing: layoutProps.isSyncing,
        lastError: layoutProps.lastError,
        onBack: layoutProps.onBack,
        onSelect: layoutProps.onSelect,
        onContinue: layoutProps.onContinue,
        onRefresh: layoutProps.onRefresh,
      );
    }

    return SellerSelectMobileLayout(
      sellers: layoutProps.sellers,
      selected: layoutProps.selected,
      confirming: layoutProps.confirming,
      isSyncing: layoutProps.isSyncing,
      lastError: layoutProps.lastError,
      onBack: layoutProps.onBack,
      onSelect: layoutProps.onSelect,
      onContinue: layoutProps.onContinue,
      onRefresh: layoutProps.onRefresh,
    );
  }
}
