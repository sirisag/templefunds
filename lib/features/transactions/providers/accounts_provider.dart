import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/core/database/database_helper.dart';
import 'package:templefunds/core/models/account_model.dart';

/// A provider that fetches all accounts from the database.
/// This is used to populate dropdowns for selecting an account.
final allAccountsProvider = FutureProvider.autoDispose<List<Account>>((ref) async {
  return DatabaseHelper.instance.getAllAccounts();
});