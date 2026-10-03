import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/theme/app_theme_palette.dart';

/// حقل إدخال فاخر: عنوان طافٍ ذهبي (floating label جاهز من
/// Flutter نفسه)، أيقونة تنبض وتتحول للذهبي عند التركيز/الكتابة،
/// وتحقق فوري (Inline Validation) يُظهر علامة صح خضراء أو حدًا
/// أحمر خافتًا بمجرد أن يصبح الإدخال صحيحًا أو خاطئًا — دون انتظار
/// الضغط على الزر.
class PremiumTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final Widget? suffixWidget;
  final VoidCallback? onTap;
  final bool readOnly;

  const PremiumTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.onChanged,
    this.suffixWidget,
    this.onTap,
    this.readOnly = false,
  });

  @override
  State<PremiumTextField> createState() => _PremiumTextFieldState();
}

enum _FieldValidity { neutral, valid, invalid }

class _PremiumTextFieldState extends State<PremiumTextField> {
  final _focusNode = FocusNode();
  _FieldValidity _validity = _FieldValidity.neutral;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode
        .addListener(() => setState(() => _focused = _focusNode.hasFocus));
    widget.controller.addListener(_revalidate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_revalidate);
    _focusNode.dispose();
    super.dispose();
  }

  void _revalidate() {
    final text = widget.controller.text;
    if (text.isEmpty) {
      if (_validity != _FieldValidity.neutral) {
        setState(() => _validity = _FieldValidity.neutral);
      }
      return;
    }
    if (widget.validator == null) return;
    final error = widget.validator!(text);
    final next = error == null ? _FieldValidity.valid : _FieldValidity.invalid;
    if (next != _validity) setState(() => _validity = next);
  }

  Color _iconColor(AppThemePalette p) {
    if (_validity == _FieldValidity.invalid) return p.error;
    if (_focused || widget.controller.text.isNotEmpty) return p.accent;
    return p.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget? trailing = widget.suffixWidget;
    if (trailing == null && _validity != _FieldValidity.neutral) {
      trailing = AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          _validity == _FieldValidity.valid
              ? Icons.check_circle_rounded
              : Icons.error_outline_rounded,
          key: ValueKey(_validity),
          color: _validity == _FieldValidity.valid
              ? p.success
              : p.error.withValues(alpha: 0.85),
          size: 20,
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: _focused
            ? [
                BoxShadow(
                    color: p.accent.withValues(alpha: 0.18),
                    blurRadius: 16,
                    spreadRadius: 1)
              ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textAlign: TextAlign.right,
        readOnly: widget.readOnly,
        onTap: widget.onTap,
        validator: widget.validator,
        onChanged: (v) {
          _revalidate();
          widget.onChanged?.call(v);
        },
        style: TextStyle(color: p.textPrimary),
        decoration: InputDecoration(
          labelText: widget.label,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          floatingLabelStyle:
              TextStyle(color: p.accentBright, fontWeight: FontWeight.w600),
          prefixIcon: widget.prefixIcon != null
              ? AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  scale: _focused ? 1.08 : 1.0,
                  child: Icon(widget.prefixIcon, color: _iconColor(p)),
                )
              : null,
          suffixIcon: trailing == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: 12), child: trailing),
        ),
      ),
    );
  }
}
