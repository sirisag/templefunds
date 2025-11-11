import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A service for handling AES encryption and decryption of the database file.
class CryptoService {
  /// Derives a 32-byte (256-bit) key from the given password string using SHA-256.
  /// This is a simpler and more direct method than using a key stretcher like PBKDF2.
  encrypt.Key _deriveKey(String password) {
    final passwordBytes = utf8.encode(password);
    final digest = crypto.sha256.convert(passwordBytes);
    // The digest's bytes are used directly as the key.
    // SHA-256 produces a 32-byte hash, which is the required length for AES-256.
    return encrypt.Key(Uint8List.fromList(digest.bytes));
  }

  /// Hashes a given string using SHA-256.
  String hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  /// Encrypts the given data using AES-256 with the provided password.
  /// The output format is [16-byte IV][Encrypted Data].
  Uint8List encryptData(Uint8List data, String password) {
    final key = _deriveKey(password);
    // A new, random IV must be generated for every encryption.
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );

    final encrypted = encrypter.encryptBytes(data, iv: iv);

    // Prepend the IV to the encrypted data for use during decryption.
    final builder = BytesBuilder();
    builder.add(iv.bytes);
    builder.add(encrypted.bytes);

    return builder.toBytes();
  }

  /// Decrypts the given data using AES-256 with the provided password.
  /// It expects the input format to be [16-byte IV][Encrypted Data].
  Uint8List decryptData(Uint8List encryptedData, String password) {
    if (encryptedData.length < 17) {
      throw Exception('ไฟล์ข้อมูลไม่ถูกต้องหรือเสียหาย (ขนาดเล็กเกินไป)');
    }

    final key = _deriveKey(password);
    // The IV is the first 16 bytes of the encrypted data.
    final iv = encrypt.IV(encryptedData.sublist(0, 16));
    // The actual encrypted content is the rest of the data.
    final encryptedBytes = encryptedData.sublist(16);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    final decrypted = encrypter.decryptBytes(
      encrypt.Encrypted(encryptedBytes),
      iv: iv,
    );
    return Uint8List.fromList(decrypted);
  }
}

// Provider for easy access to the service
final cryptoServiceProvider = Provider((ref) => CryptoService());
