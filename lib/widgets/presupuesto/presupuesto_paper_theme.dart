import 'package:flutter/material.dart';

/// AR-43: presupuesto is a white print sheet inside a dark app theme.
/// Without this, [InputDecorationTheme.filled] paints fields nearly black.
ThemeData presupuestoPaperTheme(ThemeData base) {
  const black = Colors.black;
  const ink = TextStyle(color: black);

  return base.copyWith(
    brightness: Brightness.light,
    colorScheme: base.colorScheme.copyWith(
      brightness: Brightness.light,
      surface: Colors.white,
      onSurface: black,
      primary: black,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: black,
      displayColor: black,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: false,
      fillColor: Colors.transparent,
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
