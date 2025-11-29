import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/core/database/database_helper.dart';
import 'package:templefunds/core/models/recovery_code_model.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';

class RecoveryCodesNotifier extends AsyncNotifier<List<RecoveryCode>> {
  late DatabaseHelper _dbHelper;
  static const int requiredCodes = 5;

  @override
  Future<List<RecoveryCode>> build() async {
    // Initialize with a non-reactive database helper.
    _dbHelper = ref.read(databaseHelperProvider);
    // Start with an empty list. The provider will be explicitly populated
    // by other parts of the app (like AuthProvider or RecoveryCodesScreen).
    return [];
  }

  Future<List<RecoveryCode>> _fetchAndEnsureCodes(int userId) async {
    final existingCodesMaps = await _dbHelper.getRecoveryCodesForUser(userId);
    final existingCodes =
        existingCodesMaps.map((map) => RecoveryCode.fromMap(map)).toList();

    final activeCodes = existingCodes.where((code) => !code.isUsed).toList();

    // --- Logic to ensure exactly `requiredCodes` are available ---
    final difference = requiredCodes - activeCodes.length;

    if (difference > 0) {
      // If we have fewer than required, generate more.
      final codesToGenerate = difference;
      for (int i = 0; i < codesToGenerate; i++) {
        await _generateAndAddCode(userId);
      }
    } else if (difference < 0) {
      // If we have more than required, delete the oldest ones.
      final codesToDeleteCount = -difference;
      activeCodes
          .sort((a, b) => a.createdAt.compareTo(b.createdAt)); // Oldest first
      final codesToDelete = activeCodes.take(codesToDeleteCount).toList();
      await _dbHelper
          .deleteRecoveryCodes(codesToDelete.map((c) => c.id).toList());
    }

    // Re-fetch the final, correct list of codes.
    final allCodesMaps = await _dbHelper.getRecoveryCodesForUser(userId);
    return allCodesMaps.map((map) => RecoveryCode.fromMap(map)).toList();
  }

  Future<void> _generateAndAddCode(int userId) async {
    final random = Random();
    // Generate a 10-digit code by building a string of random digits.
    // This avoids large integer overflows on 32-bit systems.
    String newCode = (random.nextInt(9) + 1) // First digit is 1-9
        .toString();
    for (int i = 0; i < 9; i++) {
      newCode += random.nextInt(10).toString(); // Subsequent 9 digits are 0-9
    }

    await _dbHelper.addRecoveryCode(
      userId,
      newCode,
      DateTime.now(),
      // Explicitly set is_tagged to 0, even though DB has a default.
      // This makes the code more robust.
    );
  }

  Future<void> regenerateCodes([int? userId]) async {
    final effectiveUserId = userId ?? ref.read(authProvider).user?.id;

    if (effectiveUserId == null) {
      state = AsyncValue.error('ไม่พบผู้ใช้งาน', StackTrace.current);
      return; // No user to generate codes for
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchAndEnsureCodes(effectiveUserId));
  }

  /// Invalidates all current codes and generates a completely new set.
  Future<void> regenerateAllNewCodes() async {
    final user = ref.read(authProvider).user;
    if (user == null || user.id == null) {
      return;
    }
    final userId = user.id!;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // Invalidate all existing unused codes first
      await _dbHelper.invalidateAllUnusedRecoveryCodes(userId);
      // Then, fetch and ensure new codes are generated
      return _fetchAndEnsureCodes(userId);
    });
  }

  /// Toggles the tagged status of a code.
  Future<void> toggleCodeTag(RecoveryCode code) async {
    await _dbHelper.toggleRecoveryCodeTag(code.id, code.isTagged);
    // Refresh the state to show the change immediately
    state = await AsyncValue.guard(() async {
      final user = ref.read(authProvider).user;
      if (user == null) throw Exception('ไม่พบผู้ใช้งาน');
      return _fetchAndEnsureCodes(user.id!);
    });
  }
}

final recoveryCodesProvider =
    AsyncNotifierProvider<RecoveryCodesNotifier, List<RecoveryCode>>(() {
  return RecoveryCodesNotifier();
});
