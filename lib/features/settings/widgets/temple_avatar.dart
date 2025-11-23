import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';

class TempleAvatar extends ConsumerWidget {
  final double radius;

  const TempleAvatar({
    super.key,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logoAsync = ref.watch(templeLogoProvider);

    return logoAsync.when(
      data: (logoPath) {
        ImageProvider? backgroundImage;
        if (logoPath != null && File(logoPath).existsSync()) {
          backgroundImage = FileImage(File(logoPath));
        }

        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: backgroundImage,
          child: backgroundImage == null
              ? Icon(Icons.account_balance_outlined,
                  color: Colors.grey.shade600, size: radius)
              : null,
        );
      },
      loading: () => CircleAvatar(radius: radius),
      error: (e, s) =>
          CircleAvatar(radius: radius, child: const Icon(Icons.error_outline)),
    );
  }
}
