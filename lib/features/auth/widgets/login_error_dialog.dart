import 'dart:async';

import 'package:flutter/material.dart';

/// A dialog that displays a login error message and an optional lockout countdown.
class LoginErrorDialog extends StatefulWidget {
  final String errorMessage;
  final DateTime? lockoutUntil;

  const LoginErrorDialog({
    super.key,
    required this.errorMessage,
    this.lockoutUntil,
  });

  @override
  State<LoginErrorDialog> createState() => _LoginErrorDialogState();
}

class _LoginErrorDialogState extends State<LoginErrorDialog> {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.lockoutUntil != null) {
      _remainingTime = widget.lockoutUntil!.difference(DateTime.now());
      if (_remainingTime.isNegative) {
        _remainingTime = Duration.zero;
      }
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        setState(() {
          _remainingTime = _remainingTime - const Duration(seconds: 1);
        });
      } else {
        _timer?.cancel();
        // Force a rebuild to enable the button
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.lockoutUntil != null && _remainingTime.inSeconds > 0;
    final countdownText =
        'กรุณารออีก ${_remainingTime.inMinutes}:${(_remainingTime.inSeconds % 60).toString().padLeft(2, '0')}';

    return AlertDialog(
      title: const Text('เกิดข้อผิดพลาด'),
      content: Text(
        isLocked ? '$countdownText\n\n${widget.errorMessage}' : widget.errorMessage,
      ),
      actions: [
        TextButton(
          // Disable the button if locked out
          onPressed: isLocked ? null : () => Navigator.of(context).pop(),
          child: const Text('ตกลง'),
        ),
      ],
    );
  }
}