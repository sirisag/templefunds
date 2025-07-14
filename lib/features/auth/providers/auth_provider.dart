import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/account_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/secure_storage_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
//import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
//import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/crypto_service.dart';
import '../../settings/providers/settings_provider.dart';

// Part 1: Define the possible authentication states
enum AuthStatus {
  initializing,   // Initial state on app start
  loggedOut,      // Initial state, user needs to enter ID1
  requiresAdminRegistration, // No DB found, new admin setup
  requiresId2,    // ID1 was correct, now needs ID2
  requiresPin,    // User is recognized on this device, needs PIN
  requiresPinSetup, // First time login on this device, needs to set a PIN
  loggedIn,       // Successfully logged in
}

// Part 2: Define the state object that will be managed
class AuthState {
  final AuthStatus status;
  final User? user; // The user object when logged in or partially identified
  final String? errorMessage;
  final DateTime? lastDbExport;
  final DateTime? lockoutUntil;

  AuthState({
    this.status = AuthStatus.initializing,
    this.user,
    this.errorMessage,
    this.lastDbExport,
    this.lockoutUntil,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    DateTime? lastDbExport,
    DateTime? lockoutUntil,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage, // Allow clearing the error message
      lastDbExport: lastDbExport ?? this.lastDbExport,
      lockoutUntil: lockoutUntil,
    );
  }
}

// Part 3: Create the StateNotifier
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final DatabaseHelper _dbHelper;
  final SecureStorageService _secureStorage;

  AuthNotifier(this._ref, this._dbHelper, this._secureStorage) : super(AuthState()) {
    _init();
  }

  Future<void> _init() async {
    // Check for an existing lockout on app start
    if (await _isCurrentlyLockedOut()) {
      return;
    }

    try {
      final lastUserId = await _secureStorage.getLastUserId();
      final lastDbExport = await _secureStorage.getLastDbExportTimestamp();
      // A PIN is considered set if we have a last user ID.
      if (lastUserId != null) {
        final user = await _dbHelper.getUserById(lastUserId);
        if (user != null) {
          // User is recognized, go straight to the PIN screen
          state = state.copyWith(
              status: AuthStatus.requiresPin,
              user: user,
              lastDbExport: lastDbExport);
        } else {
          // Data inconsistency (e.g., new DB imported), force full logout
          await logout();
        }
      } else {
        // No user saved, normal logged-out state
        state =
            state.copyWith(status: AuthStatus.loggedOut, lastDbExport: lastDbExport);
      }
    } catch (e) {
      // Error during init, default to logged out
      state = state.copyWith(status: AuthStatus.loggedOut, errorMessage: 'เกิดข้อผิดพลาดในการเริ่มต้น');
    }
  }

  /// Checks if the user is currently locked out and updates the state if so.
  /// Returns true if locked out, false otherwise.
  Future<bool> _isCurrentlyLockedOut() async {
    final lockoutTime = await _secureStorage.getLockoutEndTime();
    if (lockoutTime != null && lockoutTime.isAfter(DateTime.now())) {
      state = state.copyWith(
        // Keep the current status (e.g., loggedOut or requiresPin)
        status: state.status,
        errorMessage: 'มีการพยายามเข้าสู่ระบบผิดพลาดหลายครั้ง กรุณารอ',
        lockoutUntil: lockoutTime,
      );
      return true;
    }
    return false;
  }

  /// Handles the logic for a failed login attempt.
  Future<void> _handleLoginFailure({required String baseErrorMessage}) async {
    final newFailureCount = await _secureStorage.incrementLoginFailureCount();
    const lockoutThreshold = 4;

    if (newFailureCount >= lockoutThreshold) {
      // Lockout duration increases by 1 minute for each failure after the 2nd.
      final lockoutMinutes = newFailureCount - (lockoutThreshold - 1);
      final lockoutEndTime = DateTime.now().add(Duration(minutes: lockoutMinutes));
      await _secureStorage.setLockoutEndTime(lockoutEndTime);
      state = state.copyWith(
        // Keep current status, but show lockout info
        status: state.status,
        errorMessage: '$baseErrorMessage และถูกล็อกชั่วคราว',
        lockoutUntil: lockoutEndTime,
      );
    } else {
      state = state.copyWith(
        status: state.status,
        errorMessage: baseErrorMessage,
      );
    }
  }

  /// This is the main entry point from the WelcomeScreen.
  /// It checks if a database exists to decide if this is a first-time Admin setup
  /// or a login attempt for an existing database.
  Future<void> processId1(String userId1) async {
    if (await _isCurrentlyLockedOut()) return;
    try {
      // We need to check if the database file already exists on the device.
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'temple_funds.db');
      final dbExists = await databaseExists(path);

      if (dbExists) {
        // Database exists, so this is a login attempt.
        final user = await _dbHelper.getUserByUserId1(userId1);
        if (user == null) {
          throw Exception('ไม่พบผู้ใช้งานรหัสนี้ในไฟล์ข้อมูล');
        }
        // User found, now we need ID2
        await _secureStorage.resetLoginFailureCount();
        state = state.copyWith(status: AuthStatus.requiresId2, user: user, errorMessage: null, lockoutUntil: null);
      } else {
        // No database, this is a new Admin registration flow.
        final tempAdmin = User(userId1: userId1, userId2: '', name: '', role: 'Admin', createdAt: DateTime.now());
        state = state.copyWith(status: AuthStatus.requiresAdminRegistration, user: tempAdmin, errorMessage: null, lockoutUntil: null);
      }
    } catch (e) {
      await _handleLoginFailure(baseErrorMessage: e.toString().replaceFirst("Exception: ", ""));
    }
  }

  // This would be called from the ID2 verification screen
  Future<void> verifyId2(String userId2) async {
    if (await _isCurrentlyLockedOut()) return;
    if (state.user == null) return;

    if (state.user!.userId2 == userId2) {
      // ID2 is correct! Move to PIN setup.
      await _secureStorage.resetLoginFailureCount();
      state = state.copyWith(status: AuthStatus.requiresPinSetup, errorMessage: null, lockoutUntil: null);
    } else {
      // Handle failure. The _handleLoginFailure method will update the state
      // with an error message and potential lockout, while keeping the status as requiresId2.
      await _handleLoginFailure(baseErrorMessage: 'รหัสยืนยันตัวตนไม่ถูกต้อง');
    }
  }

  // This would be called from the PIN screen
  Future<void> setPinAndLogin(String pin) async {
    if (state.user?.id == null) return; // Should not happen, but good practice
    await _secureStorage.resetLoginFailureCount(); // Reset on successful setup
    await _secureStorage.savePin(pin);
    await _secureStorage.saveLastUserId(state.user!.id!);
    state = state.copyWith(status: AuthStatus.loggedIn, user: state.user, errorMessage: null, lockoutUntil: null);
  }

  // This would be called from the PIN screen
  Future<void> loginWithPin(String pin) async {
    if (await _isCurrentlyLockedOut()) return;

    final isPinCorrect = await _secureStorage.verifyPin(pin);
    if (isPinCorrect) {
      await _secureStorage.resetLoginFailureCount();
      state = state.copyWith(status: AuthStatus.loggedIn, user: state.user, errorMessage: null, lockoutUntil: null);
    } else {
      await _handleLoginFailure(baseErrorMessage: 'PIN ไม่ถูกต้อง');
    }
  }

  /// Completes the registration for a new Admin.
  Future<void> completeAdminRegistration(String name, String templeName) async {
    if (state.user == null || state.status != AuthStatus.requiresAdminRegistration) return;

    try {
      // Generate a random 4-digit ID2
      final id2 = (1000 + Random().nextInt(9000)).toString();
      
      // Create a user object without an ID first
      var adminUser = User(
        userId1: state.user!.userId1,
        userId2: id2,
        name: name,
        role: 'Admin',
        createdAt: DateTime.now(),
      );

      // This will create the DB and the user, and return the new ID
      final newId = await _dbHelper.addUser(adminUser); // This creates the user table

      // Also create the central temple account
      final templeAccount = Account(
        name: 'กองกลางวัด',
        ownerUserId: null, // No specific owner
        createdAt: DateTime.now(),
      );
      await _dbHelper.addAccount(templeAccount);

      // Save the temple name to metadata
      await _dbHelper.setAppMetadata('temple_name', templeName);

      // Invalidate the provider so other parts of the app get the new name
      _ref.invalidate(templeNameProvider);

      // Update the user object with the ID from the database
      adminUser = adminUser.copyWith(id: newId);

      // Update state to the final user object and move to PIN setup
      state = state.copyWith(status: AuthStatus.requiresPinSetup, user: adminUser, errorMessage: null);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.loggedOut, errorMessage: 'เกิดข้อผิดพลาดในการสร้างบัญชีผู้ดูแล');
    }
  }

  /// Handles the database file import process.
  Future<bool> importDatabaseFile() async {
    File? tempFile;
    try {
      // 1. Pick the file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null ) {
        return false; // User canceled
      }

      final pickedFile = result.files.single;
      final pickedFilePath = pickedFile.path!;
      final pickedFileName = pickedFile.name;

      if (pickedFileName == null) {
        throw Exception('ไม่สามารถอ่านชื่อไฟล์ที่นำเข้าได้');
      }

      final extension = p.extension(pickedFilePath).toLowerCase();
      if (extension != '.db' && extension != '.json') {
        throw Exception('กรุณาเลือกไฟล์สำรองข้อมูล (.db หรือ .json) เท่านั้น');
      }

      // 2. Read the encrypted file bytes
      final encryptedBytes = await File(pickedFilePath).readAsBytes();

      // 3. Decrypt the data
      // Extract the timestamp from the filename to use as the decryption key.
      final match = RegExp(r'_(\d{8}_\d{4})\.json$').firstMatch(pickedFileName);
      if (match == null || match.group(1) == null) {
        throw Exception('ชื่อไฟล์ไม่ถูกต้อง ไม่สามารถถอดรหัสได้');
      }
      final timestampKey = match.group(1)!.replaceAll('_', ''); // Key is yyyyMMddHHmm

      final cryptoService = _ref.read(cryptoServiceProvider);
      final decryptedBytes = cryptoService.decryptData(encryptedBytes, timestampKey);
      // 4. Define paths and write decrypted data to a temporary file for validation
      final dbDirectoryPath = await getDatabasesPath();
      final appDbPath = p.join(dbDirectoryPath, 'temple_funds.db');
      final tempDbPath = p.join(dbDirectoryPath, 'import_temp.db');
      tempFile = File(tempDbPath);
      await tempFile.writeAsBytes(decryptedBytes);

      // 5. Validate the structure of the temporary database file
      await _dbHelper.validateDatabaseFile(tempDbPath);

      // 6. If validation is successful, replace the old DB
      // Close any existing database connection to release the file lock.
      await _dbHelper.close();

      // Delete the old DB if it exists.
      final oldDbFile = File(appDbPath);
      if (await oldDbFile.exists()) {
        await oldDbFile.delete();
      }

      // Rename the validated temp file to be the main DB.
      await tempFile.rename(appDbPath);
      tempFile = null; // Prevent deletion in the finally block.

      // 7. Reset the auth state completely.
      await logout();
      return true;
    } catch (e) {
      final errorString = e.toString();
      // Check for common decryption error messages
      if (errorString.contains('Invalid argument(s): Invalid or corrupted pad block') || errorString.contains('bad padding')) {
        state = state.copyWith(errorMessage: 'นำเข้าไฟล์ไม่สำเร็จ: รหัสผ่านไม่ถูกต้อง หรือไฟล์เสียหาย');
      } else {
        state = state.copyWith(errorMessage: 'นำเข้าไฟล์ไม่สำเร็จ: ${errorString.replaceFirst("Exception: ", "")}');
      }
      return false;
    } finally {
      // Clean up the temp file if it still exists (e.g., on error).
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  /// Changes the user's PIN.
  Future<void> changePin(String oldPin, String newPin) async {
    if (state.user?.id == null) {
      throw Exception('ไม่พบผู้ใช้งานที่ล็อกอินอยู่');
    }

    final isOldPinCorrect = await _secureStorage.verifyPin(oldPin);
    if (!isOldPinCorrect) {
      throw Exception('รหัส PIN ปัจจุบันไม่ถูกต้อง');
    }

    await _secureStorage.savePin(newPin);
    // No need to save last user ID again, it's the same user.
  }

  /// Allows the user to go back from the ID2 screen to the ID1 screen.
  Future<void> goBackToId1Screen() async {
    // This resets the auth flow state without deleting the stored PIN or last user ID.
    state = AuthState(
      status: AuthStatus.loggedOut,
      user: null,
      errorMessage: null,
      lockoutUntil: null,
      lastDbExport: state.lastDbExport,
    );
  }

  /// Resets the entire application to its initial state by deleting the database and PIN.
  Future<void> resetApp() async {
    await _secureStorage.deleteAll();
    await _dbHelper.deleteDatabaseFile();
    state = AuthState(status: AuthStatus.loggedOut); // Reset to a clean loggedOut state
  }

  /// Saves the timestamp of the last successful DB export.
  Future<void> saveLastDbExportTimestamp(DateTime timestamp) async {
    await _secureStorage.saveLastDbExportTimestamp(timestamp);
    state = state.copyWith(lastDbExport: timestamp); // Update state
  }

  Future<void> logout() async {
    await _secureStorage.deleteAll();
    state = AuthState(status: AuthStatus.loggedOut); // Reset to a clean loggedOut state
  }

  /// Clears any existing error message from the state.
  void clearError() {
    if (state.errorMessage != null || state.lockoutUntil != null) {
      state = state.copyWith(errorMessage: null, lockoutUntil: null);
    }
  }
}

// Part 4: Define the provider itself
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref, DatabaseHelper.instance, SecureStorageService());
});
