import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:templefunds/core/database/database_helper.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';

/// A service to handle the database export process with confirmation and feedback.
class DbExportService {
  final Ref _ref;

  DbExportService(this._ref);

  Future<bool> exportDatabaseFile() async {
    try {
      // 1. Get the app's database path
      final dbDirectoryPath = await getDatabasesPath();
      final appDbPath = p.join(dbDirectoryPath, 'temple_funds.db');
      final dbFile = File(appDbPath);

      if (!await dbFile.exists()) {
        throw Exception('ไม่พบไฟล์ฐานข้อมูลสำหรับส่งออก');
      }

      // 2. Generate a descriptive filename
      final templeName = (await _ref.read(templeNameProvider.future) ?? 'temple').replaceAll(' ', '_');
      final timestamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
      final fileName = '${templeName}_$timestamp.db';

      // 3. Use share_plus to share the file
      final xfile = XFile(appDbPath, name: fileName);
      await Share.shareXFiles(
        [xfile],
        text: 'ไฟล์ข้อมูลแอปบันทึกปัจจัยวัด ($templeName) ณ ${DateTime.now().toLocal()}',
      );

      // On success, save the timestamp
      final now = DateTime.now();
      await _ref.read(authProvider.notifier).saveLastDbExportTimestamp(now);

      return true;
    } catch (e) {
      // Rethrow the exception to be caught by the UI layer
      throw Exception('ส่งออกไฟล์ไม่สำเร็จ: ${e.toString()}');
    }
  }
}

// Provider for easy access to the service
final dbExportServiceProvider = Provider((ref) => DbExportService(ref));