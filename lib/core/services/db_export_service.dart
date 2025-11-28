import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
//import 'dart:typed_data';
import 'package:archive/archive.dart';

//import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:templefunds/core/database/database_helper.dart';
import 'package:templefunds/core/services/crypto_service.dart';
import 'package:templefunds/core/utils/image_path_collector.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';
import 'package:image/image.dart' as img;

/// A service to handle the database export process with confirmation and feedback.
class DbExportService {
  final Ref _ref;

  DbExportService(this._ref);

  Future<bool> exportDatabaseFile() async {
    File? tempEncryptedFile;
    try {
      // 1. Get the app's database path and create a JSON structure
      final dbDirectoryPath = await getDatabasesPath();
      final appDbPath = p.join(dbDirectoryPath, 'temple_funds.db');
      final dbFile = File(appDbPath);
      if (!await dbFile.exists()) {
        throw Exception('ไม่พบไฟล์ฐานข้อมูลสำหรับส่งออก');
      }
      final rawDbBytes = await dbFile.readAsBytes();
      final base64DbData = base64Encode(rawDbBytes);

      final templeName = await _ref.read(templeNameProvider.future);
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
      final jsonBytes = utf8.encode(jsonEncode(exportData));

      // 2. Create an in-memory ZIP archive
      final archive = Archive();

      // Add the database JSON to the archive
      archive
          .addFile(ArchiveFile('database.json', jsonBytes.length, jsonBytes));

      // 3. Collect all image paths from the database
      final imagePaths = await ImagePathCollector(_ref).getAllImagePaths();
      final imageDir =
          Directory(p.join((await getApplicationDocumentsDirectory()).path));

      for (final path in imagePaths) {
        if (path == null || path.isEmpty) continue;
        final imageFile = File(path);
        if (await imageFile.exists()) {
          final relativePath = p.relative(imageFile.path, from: imageDir.path);
          final archivePath =
              p.join('images', relativePath).replaceAll(r'\', '/');

          // --- Image Resizing and Compression Logic ---
          Uint8List imageBytes = await imageFile.readAsBytes();
          final decodedImage = img.decodeImage(imageBytes);

          if (decodedImage != null) {
            // Resize the image to a max dimension of 1024px, maintaining aspect ratio
            // Resize the image to a max dimension of 800px, maintaining aspect ratio
            final resizedImage =
                img.copyResize(decodedImage, width: 800, height: 800);

            // Encode the resized image as a JPEG with 85% quality
            final compressedBytes = img.encodeJpg(resizedImage, quality: 85);
            imageBytes = Uint8List.fromList(compressedBytes);
          }
          // If decoding fails for any reason, we fall back to using the original image bytes.
          // --- End of Image Processing Logic ---

          archive
              .addFile(ArchiveFile(archivePath, imageBytes.length, imageBytes));
        }
      }

      // 4. Encode the archive to a byte stream (ZIP format)
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      if (zipBytes == null) {
        throw Exception('ไม่สามารถสร้างไฟล์ ZIP ได้');
      }

      // Sanitize the temple name to be used in a filename by replacing spaces and invalid characters with underscores.
      final exportPrefix = await _ref.read(exportFilePrefixProvider.future);
      final rawFileName = exportPrefix ?? templeName ?? 'temple_backup';
      final sanitizedFileName =
          rawFileName.replaceAll(RegExp(r'[\s\\/:*?"<>|]+'), '_');
      final timestampString =
          DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName =
          '${sanitizedFileName}_$timestampString.zip'; // Changed to .zip
      final password =
          timestampString.replaceAll('_', ''); // Key is yyyyMMddHHmm

      // 5. Encrypt the ZIP data
      final cryptoService = _ref.read(cryptoServiceProvider);
      final encryptedBytes =
          cryptoService.encryptData(Uint8List.fromList(zipBytes), password);

      // 6. Write encrypted data to a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = p.join(tempDir.path, fileName);
      tempEncryptedFile = File(tempFilePath);
      await tempEncryptedFile.writeAsBytes(encryptedBytes, flush: true);

      // 7. Use share_plus to share the temporary encrypted file
      final xfile = XFile(tempFilePath);
      final shareText =
          'ไฟล์ข้อมูลแอปบันทึกปัจจัยวัด ($rawFileName) ณ ${DateTime.now().toLocal()}';
      await Share.shareXFiles(
        [xfile],
        text: shareText,
      );

      // 8. On success, save the timestamp
      final now = DateTime.now();
      await _ref.read(authProvider.notifier).saveLastDbExportTimestamp(now);

      return true;
    } catch (e) {
      // Rethrow the exception to be caught by the UI layer
      throw Exception(
          'ส่งออกไฟล์ไม่สำเร็จ: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      // 9. Clean up the temporary file
      if (tempEncryptedFile != null && await tempEncryptedFile.exists()) {
        await tempEncryptedFile.delete();
      }
    }
  }
}

// Provider for easy access to the service
final dbExportServiceProvider = Provider((ref) => DbExportService(ref));
