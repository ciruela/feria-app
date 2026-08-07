import 'package:flutter/material.dart';

/// AR-43 / AR-51: presupuesto/comprobante is a white print sheet inside a dark
/// app theme. A partial [ColorScheme.copyWith] still leaves M3 container tones
/// dark, so disabled/read-only inputs paint near-black bands over the paper.
ThemeData presupuestoPaperTheme(ThemeData base) {
  const black = Colors.black;
  const ink = TextStyle(color: black);
  const paperScheme = ColorScheme.light(
    primary: black,
    onPrimary: Colors.white,
    secondary: black,
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: black,
    error: Color(0xFFB00020),
    onError: Colors.white,
  );

  return base.copyWith(
    brightness: Brightness.light,
    colorScheme: paperScheme,
    disabledColor: Colors.black54,
    textTheme: base.textTheme.apply(
      bodyColor: black,
      displayColor: black,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: false,
      fillColor: Colors.transparent,
      hoverColor: Colors.transparent,
      isDense: true,
      hintStyle: TextStyle(color: Colors.black54, fontSize: 12),
      labelStyle: TextStyle(color: Colors.black87, fontSize: 12),
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: black, width: 1.2),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: black, width: 1.2),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: black, width: 1.5),
      ),
      disabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: black, width: 1.2),
      ),
      contentPadding: EdgeInsets.only(bottom: 2),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: black,
      selectionColor: Color(0x33000000),
      selectionHandleColor: black,
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(textStyle: ink),
    dividerColor: black,
  );
}

/// Wraps presupuesto content so form fields stay ink-on-paper.
class PresupuestoPaperTheme extends StatelessWidget {
  const PresupuestoPaperTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: presupuestoPaperTheme(Theme.of(context)),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.black),
        child: child,
      ),
    );
  }
}
