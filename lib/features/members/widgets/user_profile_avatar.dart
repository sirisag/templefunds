import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/features/members/providers/members_provider.dart';

class UserProfileAvatar extends ConsumerWidget {
  final int userId;
  final double radius;

  const UserProfileAvatar({
    super.key,
    required this.userId,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(memberByIdProvider(userId));

    return userAsync.when(
      data: (user) {
        ImageProvider? backgroundImage;
        if (user?.profileImage != null &&
            File(user!.profileImage!).existsSync()) {
          // Use a key to force reload when the path changes
          backgroundImage = FileImage(File(user.profileImage!));
        }

        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: backgroundImage,
          child: backgroundImage == null
              ? Icon(Icons.person, color: Colors.grey.shade600, size: radius)
              : null,
        );
      },
      loading: () => CircleAvatar(radius: radius), // Placeholder while loading
      error: (e, s) => CircleAvatar(
          radius: radius,
          child: const Icon(Icons.error_outline)), // Error state
    );
  }
}
