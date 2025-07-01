import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A service class for handling secure storage operations, primarily for the user's PIN.
class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  // Define keys for storage to avoid typos.
  static const _pinKey = 'user_pin_hash';
  static const _lastUserIdKey = 'last_user_id';
  static const _lastDbExportKey = 'last_db_export_timestamp';

  /// Hashes a given PIN using SHA-256.
  /// We never store the raw PIN.
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin); // data being hashed
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Saves the hashed version of the user's PIN.
  Future<void> savePin(String pin) async {
    final hashedPin = _hashPin(pin);
    await _storage.write(key: _pinKey, value: hashedPin);
  }

  /// Saves the last logged-in user's ID.
  Future<void> saveLastUserId(int userId) async {
    await _storage.write(key: _lastUserIdKey, value: userId.toString());
  }

  /// Verifies if the provided PIN matches the stored hashed PIN.
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinKey);
    if (storedHash == null) {
      return false; // No PIN has been set.
    }
    final providedPinHash = _hashPin(pin);
    return storedHash == providedPinHash;
  }

  /// Reads the last logged-in user's ID.
  Future<int?> getLastUserId() async {
    final userIdString = await _storage.read(key: _lastUserIdKey);
    if (userIdString == null) return null;
    return int.tryParse(userIdString);
  }

  /// Saves the timestamp of the last successful DB export.
  Future<void> saveLastDbExportTimestamp(DateTime timestamp) async {
    await _storage.write(key: _lastDbExportKey, value: timestamp.toIso8601String());
  }

  /// Reads the timestamp of the last successful DB export.
  Future<DateTime?> getLastDbExportTimestamp() async {
    final timestampString = await _storage.read(key: _lastDbExportKey);
    if (timestampString == null) return null;
    return DateTime.tryParse(timestampString);
  }

  /// Deletes all stored authentication data. Useful for logout.
  Future<void> deleteAll() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _lastUserIdKey);
    await _storage.delete(key: _lastDbExportKey);
  }
}