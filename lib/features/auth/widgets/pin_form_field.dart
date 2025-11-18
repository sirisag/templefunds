import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinFormField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final bool isPinVisible;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final void Function(String)? onFieldSubmitted;

  const PinFormField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.isPinVisible,
    this.validator,
    this.focusNode,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        counterText: "",
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 4,
      obscureText: !isPinVisible,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 24, letterSpacing: 16),
      validator: (value) {
        if (value == null || value.trim().length != 4) {
          return 'กรุณากรอกรหัส PIN 4 หลัก';
        }
        return validator?.call(value);
      },
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}
