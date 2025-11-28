import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/core/database/database_helper.dart';
import 'package:templefunds/core/services/crypto_service.dart';
import 'package:templefunds/core/models/account_model.dart';
import 'package:templefunds/core/models/user_model.dart';

class MembersNotifier extends AsyncNotifier<List<User>> {
  late DatabaseHelper _dbHelper;

  @override
  Future<List<User>> build() async {
    _dbHelper = DatabaseHelper.instance;
    return _fetchUsers();
  }

  Future<List<User>> _fetchUsers() async {
    final users = await _dbHelper.getAllUsers();
    return users;
  }

  Future<void> addUser(User user) async {
    // If the new user is an Admin, they don't get a personal account.
    if (user.role == UserRole.Admin) {
      await _dbHelper.addUser(user);
    } else {
      // When adding a new user (Monk/Master), we must also create a
      // corresponding personal account for them in a single transaction.
      final newAccount = Account(
        name: 'ปัจจัยส่วนตัว ${user.nickname}',
        createdAt: DateTime.now(),
      );
      // Use separate calls now that the initial DB creation race condition is solved.
      // This needs to be a transaction to ensure both succeed or fail together.
      final newUserId = await _dbHelper.addUser(user);
      final accountWithOwner = newAccount.copyWith(ownerUserId: newUserId);
      await _dbHelper.addAccount(accountWithOwner);
    }
    ref.invalidateSelf(); // Refresh the provider
    await future; // Wait for the refresh to complete
  }

  Future<void> updateUserStatus(int userId, String currentStatus) async {
    final newStatus = currentStatus == 'active' ? 'inactive' : 'active';
    await _dbHelper.updateUserStatus(userId, newStatus);
    ref.invalidateSelf();
    await future;
  }

  Future<void> updateUserRole(int userId, String newRole) async {
    await _dbHelper.updateUserRole(userId, newRole);
    ref.invalidateSelf();
    await future;
  }

  Future<void> updateUserProfile(int userId, User user) async {
    // Get the old state before making changes
    final previousState = await future;
    try {
      // Optimistically update the state
      state = AsyncValue.data([
        for (final u in previousState)
          if (u.id == userId) user else u,
      ]);
      await _dbHelper.updateUserProfile(userId, user);
    } catch (e) {
      // If error, revert to the old state
      state = AsyncValue.data(previousState);
      // And rethrow the error to be caught by the UI
      rethrow;
    }
  }

  Future<String> resetId2(int userId) async {
    final newId2 = (1000 + Random().nextInt(9000)).toString();
    // Hash the new ID2 before updating the database
    final hashedId2 = ref.read(cryptoServiceProvider).hashString(newId2);
    await _dbHelper.updateUserId2(userId, hashedId2);
    ref.invalidateSelf();
    await future;
    return newId2;
  }

  /// Checks if a userId1 is already taken, optionally excluding a specific user ID.
  Future<bool> isUserId1Taken(String userId1, {int? excludeUserId}) async {
    final users = state.asData?.value ?? [];
    return users.any((user) =>
        user.userId1 == userId1 &&
        (excludeUserId == null || user.id != excludeUserId));
  }

  /// Checks if a nickname is already taken, optionally excluding a specific user ID.
  Future<bool> isNicknameTaken(String nickname, {int? excludeUserId}) async {
    final users = state.asData?.value ?? [];
    return users.any((user) =>
        user.nickname.toLowerCase() == nickname.toLowerCase() &&
        (excludeUserId == null || user.id != excludeUserId));
  }
}

final membersProvider = AsyncNotifierProvider<MembersNotifier, List<User>>(() {
  return MembersNotifier();
});

final memberByIdProvider = Provider.autoDispose.family<User?, int>((
  ref,
  id,
) {
  final membersAsync = ref.watch(membersProvider);
  return membersAsync.when(
    data: (members) {
      // Use firstWhereOrNull from the collection package to safely find the user.
      return members.firstWhereOrNull((user) => user.id == id);
    },
    // While loading or in error, we don't have a user.
    loading: () => null,
    error: (e, s) => null,
  );
});
