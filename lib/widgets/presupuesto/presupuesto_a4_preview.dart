import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../utils/presupuesto_page_format.dart';

/// Escala una hoja A4 fija para que se vea en pantalla como se imprime.
///
/// AR-40: evita [FittedBox], que escala el paint pero deja hit-tests / foco
/// de [TextField] (N° de serie) rotos en móvil y web.
class PresupuestoA4Preview extends StatelessWidget {
  const PresupuestoA4Preview({
    super.key,
    required this.child,
    this.maxWidth = 820,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          constraints.maxWidth,
          math.min(maxWidth, PresupuestoPageFormat.sheetWidth),
        );
        final scale = width / PresupuestoPageFormat.sheetWidth;
        final height = PresupuestoPageFormat.sheetHeight * scale;

        return SizedBox(
          width: width,
          height: height,
          child: ClipRect(
            child: _ScaledHitTarget(
              scale: scale,
              child: SizedBox(
                width: PresupuestoPageFormat.sheetWidth,
                height: PresupuestoPageFormat.sheetHeight,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Escala layout + hit testing juntos (a diferencia de [FittedBox]).
class _ScaledHitTarget extends SingleChildRenderObjectWidget {
  const _ScaledHitTarget({
    required this.scale,
    required super.child,
  });

  final double scale;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderScaledHitTarget(scale: scale);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderScaledHitTarget renderObject,
  ) {
    renderObject.scale = scale;
  }
}

class _RenderScaledHitTarget extends RenderProxyBox {
  _RenderScaledHitTarget({required double scale}) : _scale = scale;

  double _scale;
  double get scale => _scale;
  set scale(double value) {
    if (_scale == value) return;
    _scale = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.biggest;
      return;
    }
    child.layout(const BoxConstraints(), parentUsesSize: true);
    size = constraints.constrain(
      Size(child.size.width * _scale, child.size.height * _scale),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    layer = context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.diagonal3Values(_scale, _scale, 1),
      (context, offset) => context.paintChild(child, offset),
      oldLayer: layer is TransformLayer ? layer as TransformLayer? : null,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null || _scale <= 0) return false;
    return result.addWithPaintTransform(
      transform: Matrix4.diagonal3Values(_scale, _scale, 1),
      position: position,
      hitTest: (result, position) =>
          child.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    transform.scaleByDouble(_scale, _scale, 1, 1);
  }
}
