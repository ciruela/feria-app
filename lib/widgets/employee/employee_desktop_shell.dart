import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'employee_cart_panel.dart';
import 'employee_nav.dart';

/// Shell 3 columnas del handoff desktop (mocks 03–05): sidebar · contenido · carrito.
class EmployeeDesktopShell extends StatelessWidget {
  const EmployeeDesktopShell({
    super.key,
    required this.body,
    required this.selected,
    required this.onNav,
  });

  final Widget body;
  final EmployeeNavItem selected;
  final ValueChanged<EmployeeNavItem> onNav;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmployeeSidebar(selected: selected, onSelected: onNav),
          Expanded(child: ColoredBox(color: AppColors.canvas, child: body)),
          const EmployeeCartPanel(),
        ],
      ),
    );
  }
}
