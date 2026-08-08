import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Teclado numérico + casillas para PIN admin (handoff Cobre táctico).
class AdminPinEntry extends StatefulWidget {
  const AdminPinEntry({
    super.key,
    this.maxDigits = 4,
    this.wrong = false,
    this.onChanged,
    this.onSubmit,
  });

  final int maxDigits;
  final bool wrong;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmit;

  @override
  State<AdminPinEntry> createState() => AdminPinEntryState();
}

class AdminPinEntryState extends State<AdminPinEntry> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode(debugLabel: 'AdminPinEntry');
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureFocus());
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void clear() {
    _submitted = false;
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureFocus());
  }

  String get pin => _controller.text;

  void _ensureFocus() {
    if (!mounted) return;
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  void _emitSubmit(String value) {
    // Evita doble onSubmit (listener al 4º dígito + onSubmitted/check):
    // el 2º Navigator.pop se comía AuthGate y dejaba el Navigator raíz vacío
    // (_history.isNotEmpty → pantalla negra/blanca).
    if (_submitted) return;
    if (value.isEmpty) return;
    _submitted = true;
    widget.onSubmit?.call(value);
  }

  void _onControllerChanged() {
    var next = _controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (next.length > widget.maxDigits) {
      next = next.substring(0, widget.maxDigits);
    }
    if (next != _controller.text) {
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
      return;
    }

    if (!mounted) return;
    setState(() {});
    widget.onChanged?.call(next);

    if (next.length == widget.maxDigits) {
      _emitSubmit(next);
    }
  }

  void _append(String digit) {
    if (_submitted) return;
    if (_controller.text.length >= widget.maxDigits) return;
    _controller.text = '${_controller.text}$digit';
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
    _ensureFocus();
  }

  void _backspace() {
    if (_submitted) return;
    if (_controller.text.isEmpty) return;
    final next = _controller.text.substring(0, _controller.text.length - 1);
    _controller.text = next;
    _controller.selection = TextSelection.collapsed(offset: next.length);
    _ensureFocus();
  }

  void _submit() {
    _emitSubmit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final pin = _controller.text;
    final boxColor = widget.wrong ? AppColors.accent : AppColors.border;

    return SelectionContainer.disabled(
      child: GestureDetector(
        onTap: _ensureFocus,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.maxDigits, (index) {
                    final filled = index < pin.length;
                    return Container(
                      width: 44,
                      height: 52,
                      margin: EdgeInsets.only(
                        right: index < widget.maxDigits - 1 ? 10 : 0,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceTouch,
                        borderRadius:
                            BorderRadius.circular(AppDecorations.radius),
                        border: Border.all(
                          color: boxColor,
                          width: widget.wrong ? 1 : AppDecorations.hairline,
                        ),
                      ),
                      child: Text(
                        filled ? '•' : '',
                        style: AppText.display.copyWith(
                          color: widget.wrong
                              ? AppColors.accent
                              : AppColors.textPrimary,
                        ),
                      ),
                    );
                  }),
                ),
                // Teclado físico (web/desktop): el TextField es la fuente de verdad.
                Opacity(
                  opacity: 0,
                  child: SizedBox(
                    width: 220,
                    height: 52,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      showCursor: false,
                      enableInteractiveSelection: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(widget.maxDigits),
                      ],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontSize: 1, height: 1),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // AR-36: el pad táctil no debe robar el foco del teclado físico.
            ExcludeFocus(
              child: _Keypad(
                onDigit: _append,
                onBackspace: _backspace,
                onSubmit: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Column(
      children: [
        for (final row in keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (final key in row) ...[
                  Expanded(child: _Key(label: key, onTap: () => onDigit(key))),
                  if (key != row.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _Key(
                icon: Icons.backspace_outlined,
                onTap: onBackspace,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _Key(label: '0', onTap: () => onDigit('0'))),
            const SizedBox(width: 8),
            Expanded(
              child: _Key(
                icon: Icons.check_rounded,
                accent: true,
                onTap: onSubmit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    this.label,
    this.icon,
    this.accent = false,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;
  final bool accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent ? AppColors.accent : AppColors.surfaceTouch,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        child: SizedBox(
          height: 64,
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    size: 22,
                    color: accent ? AppColors.onAccent : AppColors.textMuted,
                  )
                : Text(
                    label ?? '',
                    style: AppText.numberLarge.copyWith(
                      color:
                          accent ? AppColors.onAccent : AppColors.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
