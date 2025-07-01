import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/account_model.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/secure_storage_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

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

  AuthState({
    this.status = AuthStatus.initializing,
    this.user,
    this.errorMessage,
    this.lastDbExport,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    DateTime? lastDbExport,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage, // Allow clearing the error message
      lastDbExport: lastDbExport ?? this.lastDbExport,
    );
  }
}

// Part 3: Create the StateNotifier
class AuthNotifier extends StateNotifier<AuthState> {
  final DatabaseHelper _dbHelper;
  final SecureStorageService _secureStorage;

  AuthNotifier(this._dbHelper, this._secureStorage) : super(AuthState()) {
    _init();
  }

  Future<void> _init() async {
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

  /// This is the main entry point from the WelcomeScreen.
  /// It checks if a database exists to decide if this is a first-time Admin setup
  /// or a login attempt for an existing database.
  Future<void> processId1(String userId1) async {
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
        state = state.copyWith(status: AuthStatus.requiresId2, user: user, errorMessage: null);
      } else {
        // No database, this is a new Admin registration flow.
        final tempAdmin = User(userId1: userId1, userId2: '', name: '', role: 'Admin', createdAt: DateTime.now());
        state = state.copyWith(status: AuthStatus.requiresAdminRegistration, user: tempAdmin, errorMessage: null);
      }
    } catch (e) {
      // Reset to loggedOut but with an error message to show.
      state = state.copyWith(status: AuthStatus.loggedOut, errorMessage: e.toString().replaceFirst("Exception: ", ""));
    }
  }

  // This would be called from the ID2 verification screen
  Future<void> verifyId2(String userId2) async {
    if (state.user == null) return;

    if (state.user!.userId2 == userId2) {
      // ID2 is correct! Move to PIN setup.
      state = state.copyWith(status: AuthStatus.requiresPinSetup, errorMessage: null);
    } else {
      state = state.copyWith(
          status: AuthStatus.loggedOut, errorMessage: 'รหัสยืนยันตัวตนไม่ถูกต้อง');
    }
  }

  // This would be called from the PIN screen
  Future<void> setPinAndLogin(String pin) async {
    if (state.user?.id == null) return; // Should not happen, but good practice
    await _secureStorage.savePin(pin);
    await _secureStorage.saveLastUserId(state.user!.id!);
    state = state.copyWith(status: AuthStatus.loggedIn, user: state.user, errorMessage: null);
  }

  // This would be called from the PIN screen
  Future<void> loginWithPin(String pin) async {
    final isPinCorrect = await _secureStorage.verifyPin(pin);
    if (isPinCorrect) {
      state = state.copyWith(status: AuthStatus.loggedIn, user: state.user);
    } else {
      state = state.copyWith(
          status: AuthStatus.requiresPin, errorMessage: 'PIN ไม่ถูกต้อง');
    }
  }

  /// Completes the registration for a new Admin.
  Future<void> completeAdminRegistration(String name) async {
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
    try {
      // 1. Pick the file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (result == null || result.files.single.path == null) {
        // User canceled the picker
        return false;
      }

      final pickedFilePath = result.files.single.path!;

      // 2. Get the app's database path
      final dbDirectoryPath = await getDatabasesPath();
      final appDbPath = p.join(dbDirectoryPath, 'temple_funds.db');

      // 3. Close any existing database connection to release the file lock
      await _dbHelper.close();

      // 4. Copy the picked file to the app's database directory, overwriting it
      final sourceFile = File(pickedFilePath);
      await sourceFile.copy(appDbPath);

      // 5. Reset the auth state to force the user to log in again with the new DB
      state = AuthState();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'นำเข้าไฟล์ไม่สำเร็จ: ${e.toString()}');
      return false;
    }
  }

  /// Handles the database file export process.
  Future<void> exportDatabaseFile() async {
    try {
      // 1. Get the app's database path
      final dbDirectoryPath = await getDatabasesPath();
      final appDbPath = p.join(dbDirectoryPath, 'temple_funds.db');
      final dbFile = File(appDbPath);

      if (!await dbFile.exists()) {
        throw Exception('ไม่พบไฟล์ฐานข้อมูลสำหรับส่งออก');
      }

      // 2. Use share_plus to share the file
      final xfile = XFile(appDbPath, name: 'temple_funds_backup.db');
      await Share.shareXFiles(
        [xfile],
        text: 'ไฟล์ข้อมูลแอปบันทึกปัจจัยวัด ณ ${DateTime.now().toLocal()}',
      );

      // On success, save the timestamp
      final now = DateTime.now();
      await _secureStorage.saveLastDbExportTimestamp(now);
      state = state.copyWith(lastDbExport: now); // Update state
    } catch (e) {
      // Rethrow the exception to be caught by the UI layer
      throw Exception('ส่งออกไฟล์ไม่สำเร็จ: ${e.toString()}');
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

  /// Resets the entire application to its initial state by deleting the database and PIN.
  Future<void> resetApp() async {
    await _secureStorage.deleteAll();
    await _dbHelper.deleteDatabaseFile();
    state = AuthState(status: AuthStatus.loggedOut); // Reset to a clean loggedOut state
  }

  Future<void> logout() async {
    await _secureStorage.deleteAll();
    state = AuthState(status: AuthStatus.loggedOut); // Reset to a clean loggedOut state
  }

  /// Clears any existing error message from the state.
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }
}

// Part 4: Define the provider itself
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(DatabaseHelper.instance, SecureStorageService());
});
