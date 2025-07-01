import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/core/database/database_helper.dart';
import 'package:templefunds/core/models/account_model.dart';
import 'package:templefunds/core/models/user_model.dart';

class MembersNotifier extends StateNotifier<AsyncValue<List<User>>> {
  final DatabaseHelper _dbHelper;

  MembersNotifier(this._dbHelper) : super(const AsyncValue.loading()) {
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
    // When adding a new user (Monk/Master), we must also create a
    // corresponding personal account for them in a single transaction.
    final newAccount = Account(
      name: 'ปัจจัยส่วนตัว ${user.name}',
      // ownerUserId will be set inside the transaction in the helper
      createdAt: DateTime.now(),
    );

    // Use the transactional method to ensure both are created or neither.
    await _dbHelper.createNewMemberWithAccount(user, newAccount);

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

  Future<String> resetId2(int userId) async {
    final newId2 = (1000 + Random().nextInt(9000)).toString();
    await _dbHelper.updateUserId2(userId, newId2);
    await loadUsers(); // Refresh the list
    return newId2;
  }

  Future<bool> isUserId1Taken(String userId1) async {
    return _dbHelper.checkIfUserId1Exists(userId1);
  }

  Future<bool> isNameTaken(String name) async {
    return _dbHelper.checkIfNameExists(name);
  }
}

final membersProvider =
    StateNotifierProvider<MembersNotifier, AsyncValue<List<User>>>((ref) {
  return MembersNotifier(DatabaseHelper.instance);
});

final memberByIdProvider =
    Provider.autoDispose.family<AsyncValue<User?>, int>((ref, id) {
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