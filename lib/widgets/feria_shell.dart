import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FeriaBackground extends StatelessWidget {
  const FeriaBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: child,
    );
  }
}

class FeriaPageConstraint extends StatelessWidget {
  const FeriaPageConstraint({
    super.key,
    required this.child,
    this.maxWidth = 960,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth > maxWidth ? maxWidth : constraints.maxWidth;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: child,
          ),
        );
      },
    );
  }
}

class FeriaScaffold extends StatelessWidget {
  const FeriaScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.constrainBody = true,
    this.maxContentWidth = 960,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool constrainBody;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final shouldConstrain = constrainBody && kIsWeb && width >= 720;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appBar,
      body: FeriaBackground(
        child: shouldConstrain
            ? FeriaPageConstraint(maxWidth: maxContentWidth, child: body)
            : body,
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

class FeriaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FeriaAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.bottom,
    this.showBackButton = true,
  });

  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool showBackButton;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return AppBar(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: leading ??
          (showBackButton && canPop ? const _FeriaBackButton() : null),
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: canPop ? 0 : NavigationToolbar.kMiddleSpacing,
      title: DefaultTextStyle.merge(
        style: AppText.heading,
        child: title,
      ),
      actions: actions,
      bottom: bottom,
    );
  }
}

class FeriaAppBarTitle extends StatelessWidget {
  const FeriaAppBarTitle(
    this.text, {
    super.key,
    this.badge,
  });

  final String text;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showBadge = badge != null && constraints.maxWidth > 180;

        return Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.heading,
              ),
            ),
            if (showBadge) ...[
              const SizedBox(width: 8),
              badge!,
            ],
          ],
        );
      },
    );
  }
}

class _FeriaBackButton extends StatelessWidget {
  const _FeriaBackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IconButton(
        onPressed: () => Navigator.maybePop(context),
        tooltip: 'Volver',
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surfaceTouch,
          foregroundColor: AppColors.textMuted,
          fixedSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDecorations.radius),
          ),
        ),
        icon: const Icon(Icons.chevron_left_rounded, size: 24),
      ),
    );
  }
}
