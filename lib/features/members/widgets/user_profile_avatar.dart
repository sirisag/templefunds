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
    // The provider now returns User? directly, not an AsyncValue.
    final user = ref.watch(memberByIdProvider(userId));

    // If the user is null (still loading, error, or not found), show a placeholder.
    if (user == null) {
      return CircleAvatar(
          radius: radius, backgroundColor: Colors.grey.shade200);
    }

    ImageProvider? backgroundImage;
    if (user.profileImage != null && File(user.profileImage!).existsSync()) {
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
  }
}
