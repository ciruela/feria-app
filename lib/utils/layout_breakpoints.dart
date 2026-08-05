/// Breakpoints alineados a los handoffs mobile / desktop del flujo vendedor.
class LayoutBreakpoints {
  LayoutBreakpoints._();

  static const double mobile = 720;
  static const double desktop = 960;
  static const double wideDesktop = 1200;

  static bool isMobile(double width) => width < mobile;
  static bool isDesktop(double width) => width >= desktop;
}
