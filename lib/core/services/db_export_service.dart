import 'dart:io';
import 'dart:convert';
//import 'dart:typed_data';

//import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:templefunds/core/database/database_helper.dart';
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
      // 1. Get the app's database path and read its content
      final dbDirectoryPath = await getDatabasesPath();
      final appDbPath = p.join(dbDirectoryPath, 'temple_funds.db');
      final dbFile = File(appDbPath);

      if (!await dbFile.exists()) {
        throw Exception('ไม่พบไฟล์ฐานข้อมูลสำหรับส่งออก');
      }
      final rawDbBytes = await dbFile.readAsBytes();
      final base64DbData = base64Encode(rawDbBytes);

      // 2. Generate a descriptive filename to be used as the password
      // Use the configured export prefix. Fallback to temple name, then to a default.
      final exportPrefix = await _ref.read(exportFilePrefixProvider.future);
      final templeName = await _ref.read(templeNameProvider.future);
      final rawFileName = exportPrefix ?? templeName ?? 'temple_backup';
      final templeId =
          await _ref.read(databaseHelperProvider).getAppMetadata('temple_id');

      // Create the JSON structure with metadata
      final exportData = {
        'metadata': {
          'temple_id': templeId,
          'temple_name': templeName, // Keep original temple name in metadata
          'export_timestamp': DateTime.now().toIso8601String(),
          'app_version': '1.0.0', // Example version
        },
        'data': base64DbData,
      };
      final jsonString = jsonEncode(exportData);
      final jsonBytes = utf8.encode(jsonString);

      // Sanitize the temple name to be used in a filename by replacing spaces and invalid characters with underscores.
      final sanitizedFileName =
          rawFileName.replaceAll(RegExp(r'[\s\\/:*?"<>|]+'), '_');
      final timestampString =
          DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = '${sanitizedFileName}_$timestampString.json';
      final password =
          timestampString.replaceAll('_', ''); // Key is yyyyMMddHHmm

      // 3. Encrypt the data
      final cryptoService = _ref.read(cryptoServiceProvider);
      final encryptedBytes = cryptoService.encryptData(jsonBytes, password);

      // 4. Write encrypted data to a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = p.join(tempDir.path, fileName);
      tempEncryptedFile = File(tempFilePath);
      await tempEncryptedFile.writeAsBytes(encryptedBytes, flush: true);

      // 5. Use share_plus to share the temporary encrypted file with its final name
      final xfile = XFile(tempFilePath);
      final shareText =
          'ไฟล์ข้อมูลแอปบันทึกปัจจัยวัด ($rawFileName) ณ ${DateTime.now().toLocal()}';
      await Share.shareXFiles(
        [xfile],
        text: shareText,
      );

      // 6. On success, save the timestamp
      final now = DateTime.now();
      await _ref.read(authProvider.notifier).saveLastDbExportTimestamp(now);

      return true;
    } catch (e) {
      // Rethrow the exception to be caught by the UI layer
      throw Exception(
          'ส่งออกไฟล์ไม่สำเร็จ: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      // 7. Clean up the temporary file
      if (tempEncryptedFile != null && await tempEncryptedFile.exists()) {
        await tempEncryptedFile.delete();
      }
    }
  }
}

// Provider for easy access to the service
final dbExportServiceProvider = Provider((ref) => DbExportService(ref));
