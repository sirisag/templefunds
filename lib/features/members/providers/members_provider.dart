import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/core/database/database_helper.dart';
import 'package:templefunds/core/services/crypto_service.dart';
import 'package:templefunds/core/models/account_model.dart';
import 'package:templefunds/core/models/user_model.dart';

class MembersNotifier extends StateNotifier<AsyncValue<List<User>>> {
  final DatabaseHelper _dbHelper;
  final Ref _ref; // Add ref

  // Update constructor to accept Ref
  MembersNotifier(this._dbHelper, this._ref)
      : super(const AsyncValue.loading()) {
    loadUsers();
  }

  Future<void> loadUsers() async {
    try {
      state = const AsyncValue.loading();
      final users = await _dbHelper.getAllUsers();
      state = AsyncValue.data(users);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
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
    await loadUsers(); // Refresh the list to reflect the new user
  }

  Future<void> updateUserStatus(int userId, String currentStatus) async {
    final newStatus = currentStatus == 'active' ? 'inactive' : 'active';
    await _dbHelper.updateUserStatus(userId, newStatus);
    await loadUsers(); // Refresh the list
  }

  Future<void> updateUserRole(int userId, String newRole) async {
    await _dbHelper.updateUserRole(userId, newRole);
    await loadUsers(); // Refresh the list
  }

  Future<void> updateUserProfile(int userId, User user) async {
    try {
      await _dbHelper.updateUserProfile(userId, user);
      // Optimistically update the state
      state = state.whenData((users) {
        return [
          for (final u in users)
            if (u.id == userId) user else u,
        ];
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
    // No need to call loadUsers() here, as we optimistically updated the state.
  }

  Future<String> resetId2(int userId) async {
    final newId2 = (1000 + Random().nextInt(9000)).toString();
    // Hash the new ID2 before updating the database
    final hashedId2 = _ref.read(cryptoServiceProvider).hashString(newId2);
    await _dbHelper.updateUserId2(userId, hashedId2);
    await loadUsers(); // Refresh the list
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

final membersProvider =
    StateNotifierProvider<MembersNotifier, AsyncValue<List<User>>>((ref) {
  // Pass ref to the constructor
  return MembersNotifier(DatabaseHelper.instance, ref);
});

final memberByIdProvider = Provider.autoDispose.family<AsyncValue<User?>, int>((
  ref,
  id,
) {
  final membersAsync = ref.watch(membersProvider);
  return membersAsync.when(
    data: (members) {
      // Use firstWhereOrNull from the collection package to safely find the user.
      final user = members.firstWhereOrNull((user) => user.id == id);
      return AsyncValue.data(user);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});
