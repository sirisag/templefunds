import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/core/database/database_helper.dart';

/// A provider to fetch the temple name from the database.
/// It will be cached and only re-fetched when invalidated.
final templeNameProvider = FutureProvider<String?>((ref) async {
  // This provider does not need to be autoDispose because the temple name
  // is unlikely to change during a session.
  final dbHelper = DatabaseHelper.instance;
  return dbHelper.getAppMetadata('temple_name');
});