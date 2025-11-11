import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/auth/screens/welcome_screen.dart';

/// Shows a confirmation dialog for logging out.
/// Can be called from any widget that has access to [BuildContext] and [WidgetRef].
Future<void> showLogoutConfirmationDialog(BuildContext context, WidgetRef ref) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('ยืนยันการออกจากระบบ'),
      content: const Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
      actions: [
        TextButton(
          child: const Text('ยกเลิก'),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
        TextButton(
          child: const Text('ตกลง'),
          onPressed: () async {
            // Close the dialog first.
            Navigator.of(ctx).pop();
            // Perform the logout logic.
            await ref.read(authProvider.notifier).logout();
            // After logout, explicitly navigate back to the WelcomeScreen and
            // clear the entire navigation stack to prevent any old screens from
            // remaining. This provides a clean and predictable user experience.
            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              (route) => false,
            );
          },
        ),
      ],
    ),
  );
}

/// Shows a generic confirmation dialog.
/// Returns `true` if confirmed, `false` if canceled, and `null` if dismissed.
Future<bool?> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String content,
  String confirmText = 'ตกลง',
  String cancelText = 'ยกเลิก',
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          child: Text(cancelText),
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        TextButton(
          child: Text(confirmText),
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
}
