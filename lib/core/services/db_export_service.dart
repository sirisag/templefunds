import 'dart:io';
//import 'dart:typed_data';

//import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
//import 'package:templefunds/core/database/database_helper.dart';
import 'package:templefunds/core/services/crypto_service.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';

/// A service to handle the database export process with confirmation and feedback.
class DbExportService {
  final Ref _ref;

  DbExportService(this._ref);

  Future<bool> exportDatabaseFile() async {
    File? tempEncryptedFile;
    try {
      // 1. Get current user to create the password
      final user = _ref.read(authProvider).user;
      
      // 2. Get the app's database path and read its content
      final dbDirectoryPath = await getDatabasesPath();
      final appDbPath = p.join(dbDirectoryPath, 'temple_funds.db');
      final dbFile = File(appDbPath);

      if (!await dbFile.exists()) {
        throw Exception('ไม่พบไฟล์ฐานข้อมูลสำหรับส่งออก');
      }
      final dbBytes = await dbFile.readAsBytes();

      // 3. Generate a descriptive filename to be used as the password
      final rawTempleName = await _ref.read(templeNameProvider.future) ?? 'temple';
      // Sanitize the temple name to be used in a filename by replacing spaces and invalid characters with underscores.
      final sanitizedTempleName = rawTempleName.replaceAll(RegExp(r'[\s\\/:*?"<>|]+'), '_');
      final timestampString = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = '${sanitizedTempleName}_$timestampString.json';
      final password = timestampString.replaceAll('_', ''); // Key is yyyyMMddHHmm

      // 4. Encrypt the data
      final cryptoService = _ref.read(cryptoServiceProvider);
      final encryptedBytes = cryptoService.encryptData(dbBytes, password);

      // 5. Write encrypted data to a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = p.join(tempDir.path, fileName);
      tempEncryptedFile = File(tempFilePath);
      await tempEncryptedFile.writeAsBytes(encryptedBytes, flush: true);

      // 6. Use share_plus to share the temporary encrypted file with its final name
      final xfile = XFile(tempFilePath);
      final shareText = 'ไฟล์ข้อมูลแอปบันทึกปัจจัยวัด ($rawTempleName) ณ ${DateTime.now().toLocal()}';
      await Share.shareXFiles(
        [xfile],
        text: shareText,
      );

      // 7. On success, save the timestamp
      final now = DateTime.now();
      await _ref.read(authProvider.notifier).saveLastDbExportTimestamp(now);

      return true;
    } catch (e) {
      // Rethrow the exception to be caught by the UI layer
      throw Exception('ส่งออกไฟล์ไม่สำเร็จ: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      // 8. Clean up the temporary file
      if (tempEncryptedFile != null && await tempEncryptedFile.exists()) {
        await tempEncryptedFile.delete();
      }
    }
  }
}

// Provider for easy access to the service
final dbExportServiceProvider = Provider((ref) => DbExportService(ref));