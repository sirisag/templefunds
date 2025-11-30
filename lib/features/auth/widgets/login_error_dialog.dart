import 'package:flutter/material.dart';

/// A dialog that displays a login error message and an optional lockout countdown.
class LoginErrorDialog extends StatelessWidget {
  final String errorMessage;

  const LoginErrorDialog({
    super.key,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เกิดข้อผิดพลาด'),
      content: Text(errorMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ตกลง'),
        ),
      ],
    );
  }
}
