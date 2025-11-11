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
  static const _loginFailureCountKey = 'login_failure_count';
  static const _lockoutEndTimeKey = 'lockout_end_time';

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
    await _storage.write(
        key: _lastDbExportKey, value: timestamp.toIso8601String());
  }

  /// Reads the timestamp of the last successful DB export.
  Future<DateTime?> getLastDbExportTimestamp() async {
    final timestampString = await _storage.read(key: _lastDbExportKey);
    if (timestampString == null) return null;
    return DateTime.tryParse(timestampString);
  }

  /// Gets the current number of consecutive login failures.
  Future<int> getLoginFailureCount() async {
    final countString = await _storage.read(key: _loginFailureCountKey);
    return int.tryParse(countString ?? '0') ?? 0;
  }

  /// Increments the login failure count and returns the new count.
  Future<int> incrementLoginFailureCount() async {
    final currentCount = await getLoginFailureCount();
    final newCount = currentCount + 1;
    await _storage.write(
        key: _loginFailureCountKey, value: newCount.toString());
    return newCount;
  }

  /// Resets the login failure count to 0 and clears any lockout.
  Future<void> resetLoginFailureCount() async {
    await _storage.delete(key: _loginFailureCountKey);
    await _storage.delete(key: _lockoutEndTimeKey);
  }

  /// Gets the time when the current lockout period ends.
  Future<DateTime?> getLockoutEndTime() async {
    final timeString = await _storage.read(key: _lockoutEndTimeKey);
    if (timeString == null) return null;
    return DateTime.tryParse(timeString);
  }

  /// Sets the time when the lockout period should end.
  Future<void> setLockoutEndTime(DateTime endTime) async {
    await _storage.write(
        key: _lockoutEndTimeKey, value: endTime.toIso8601String());
  }

  /// Deletes only the authentication-related data, preserving other settings.
  Future<void> deleteAuthCredentials() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _lastUserIdKey);
    await resetLoginFailureCount(); // This also clears lockout time
  }

  /// Deletes all stored authentication data. Useful for logout.
  Future<void> deleteAll() async {
    // This method now deletes everything, including non-auth data that might be in secure storage.
    // For a standard logout, use `deleteAuthCredentials` instead.
    await deleteAuthCredentials();
    await _storage.delete(key: _lastDbExportKey);
  }
}
