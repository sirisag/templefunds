import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/features/members/providers/members_provider.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';
import 'package:templefunds/features/transactions/providers/transactions_provider.dart';

/// A utility class to collect all unique image paths from the database.
class ImagePathCollector {
  final Ref _ref;

  ImagePathCollector(this._ref);

  /// Fetches all unique, non-null image paths from users, transactions, and settings.
  Future<Set<String?>> getAllImagePaths() async {
    final imagePaths = <String?>{};

    // 1. Get paths from members (profile images)
    final members = await _ref.read(membersProvider.future);
    for (final member in members) {
      imagePaths.add(member.profileImage);
    }

    // 2. Get paths from transactions (receipt images)
    final transactions = await _ref.read(transactionsProvider.future);
    for (final transaction in transactions) {
      imagePaths.add(transaction.receiptImage);
    }

    // 3. Get path from settings (temple logo)
    imagePaths.add(await _ref.read(templeLogoProvider.future));

    return imagePaths.where((p) => p != null && p.isNotEmpty).toSet();
  }
}
