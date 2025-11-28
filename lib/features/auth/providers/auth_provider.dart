import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/account_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/secure_storage_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/crypto_service.dart';
import '../../transactions/providers/accounts_provider.dart';
import '../../settings/providers/settings_provider.dart';

// Part 1: Define the possible authentication states
enum AuthStatus {
  initializing, // Initial state on app start
  loggedOut, // Initial state, user needs to enter ID1
  requiresAdminRegistration, // No DB found, new admin setup
  requiresId2, // ID1 was correct, now needs ID2
  requiresLogin, // DB exists, but no user is logged in on this device yet.
  requiresPin, // User is recognized on this device, needs PIN
  requiresPinSetup, // First time login on this device, needs to set a PIN
  loggedIn, // Successfully logged in
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
class AuthNotifier extends Notifier<AuthState> {
  late DatabaseHelper _dbHelper;
  late SecureStorageService _secureStorage;

  @override
  AuthState build() {
    _dbHelper = DatabaseHelper.instance;
    _secureStorage = SecureStorageService();
    _init();
    // Return the initial state. The _init method will update it asynchronously.
    return AuthState();
  }

  Future<void> _init() async {
    debugPrint("[Auth] Initializing authentication state...");
    // Check for an existing lockout on app start
    if (await _isCurrentlyLockedOut()) {
      debugPrint("[Auth] User is currently locked out. Initialization halted.");
      return;
    }

    try {
      debugPrint("[Auth] Reading last user ID from secure storage...");
      final lastUserId = await _secureStorage.getLastUserId();
      debugPrint("[Auth] Found last user ID: $lastUserId");
      final lastDbExport = await _secureStorage.getLastDbExportTimestamp();
      // A PIN is considered set if we have a last user ID.
      if (lastUserId != null) {
        debugPrint(
          "[Auth] Fetching user data from database for ID: $lastUserId",
        );
        final user = await _dbHelper.getUserById(lastUserId);
        if (user != null) {
          // Check if the user is active before allowing PIN login
          if (user.status != 'active') {
            debugPrint("[Auth] User ${user.id} is inactive. Forcing logout.");
            await logout(); // Force logout for inactive user
            return;
          }
          // User is recognized, go straight to the PIN screen
          debugPrint("[Auth] User found. Setting state to requiresPin.");
          state = state.copyWith(
            status: AuthStatus.requiresPin,
            user: user,
            lastDbExport: lastDbExport,
          );
        } else {
          debugPrint(
            "[Auth] User ID found in storage, but not in DB. Forcing logout.",
          );
          // Data inconsistency (e.g., new DB imported), force full logout
          await logout();
        }
      } else {
        // No user saved on this device. Check if a database exists.
        final dbPath = await getDatabasesPath();
        final path = p.join(dbPath, 'temple_funds.db');
        final dbExists = await databaseExists(path);

        if (dbExists) {
          // DB exists, but no user logged in here. Go to the generic login screen.
          // FIX: Change the state to loggedOut to show the WelcomeScreen first,
          // instead of forcing the LoginScreen. The user can then choose to log in.
          debugPrint(
              "[Auth] DB exists, but no user saved. Setting state to loggedOut.");
          state = state.copyWith(
              status: AuthStatus.loggedOut, lastDbExport: lastDbExport);
        } else {
          // No DB, no user. This is a fresh install.
          debugPrint("[Auth] No DB or user found. Setting state to loggedOut.");
          state = state.copyWith(
              status: AuthStatus.loggedOut, lastDbExport: lastDbExport);
        }
      }
    } catch (e) {
      // Error during init, default to logged out
      debugPrint("[Auth] Error during initialization: $e");
      state = state.copyWith(
        status: AuthStatus.loggedOut,
        errorMessage: 'เกิดข้อผิดพลาดในการเริ่มต้น',
      );
    }
    debugPrint("[Auth] Initialization complete. Final status: ${state.status}");
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
      final lockoutEndTime = DateTime.now().add(
        Duration(minutes: lockoutMinutes),
      );
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

  // This would be called from the PIN screen
  Future<void> setPinAndLogin(String pin) async {
    if (state.user?.id == null) return; // Should not happen, but good practice
    await _secureStorage.resetLoginFailureCount(); // Reset on successful setup
    await _secureStorage.savePin(pin);
    await _secureStorage.saveLastUserId(state.user!.id!);
    state = state.copyWith(
      status: AuthStatus.loggedIn,
      user: state.user,
      errorMessage: null,
      lockoutUntil: null,
    );
  }

  // This would be called from the PIN screen
  Future<void> loginWithPin(String pin) async {
    if (await _isCurrentlyLockedOut()) return;

    final isPinCorrect = await _secureStorage.verifyPin(pin);
    if (isPinCorrect) {
      await _secureStorage.resetLoginFailureCount();
      // Explicitly set the status to loggedIn on successful PIN verification.
      // The previous code was missing this, causing the UI to get stuck.
      state = AuthState(
        status: AuthStatus.loggedIn,
        user: state.user,
        errorMessage: null,
        lockoutUntil: null,
        lastDbExport: state.lastDbExport,
      );
    } else {
      await _handleLoginFailure(baseErrorMessage: 'PIN ไม่ถูกต้อง');
    }
  }

  /// New method for the combined login screen.
  Future<void> loginWithIds({required String id1, required String id2}) async {
    if (await _isCurrentlyLockedOut()) return;
    try {
      final user = await _dbHelper.getUserByUserId1(id1);
      if (user == null) {
        throw Exception('ไม่พบผู้ใช้งานรหัสนี้');
      }

      // Hash the provided ID2 and compare
      final hashedId2 = ref.read(cryptoServiceProvider).hashString(id2);
      if (user.userId2 != hashedId2) {
        throw Exception('รหัสยืนยันตัวตนไม่ถูกต้อง');
      }

      // Check if the user is active
      if (user.status != 'active') {
        throw Exception('บัญชีผู้ใช้นี้ถูกระงับการใช้งาน');
      }

      // Credentials are correct
      await _secureStorage.resetLoginFailureCount();
      state = state.copyWith(
        status: AuthStatus.requiresPinSetup,
        user: user,
        errorMessage: null,
        lockoutUntil: null,
      );
    } catch (e) {
      await _handleLoginFailure(
        baseErrorMessage: e.toString().replaceFirst("Exception: ", ""),
      );
    }
  }

  /// New method for the temple registration screen.
  Future<String?> registerNewTemple({
    required String templeName,
    required String nickname,
    String? firstName,
    String? lastName,
    String? ordinationName,
    String? specialTitle,
    String? phoneNumber,
    String? email,
    required String adminId1,
    required String pin,
    File? logoImageFile,
    File? adminProfileImageFile,
  }) async {
    try {
      // Force delete any existing database file and close any open connections.
      // This ensures a completely fresh start, mimicking the "reset" functionality
      // and preventing issues with stale database handles.
      await _dbHelper.deleteDatabaseFile();

      // 1. Create Admin User
      final adminId2 = (1000 + Random().nextInt(9000)).toString();
      final hashedAdminId2 =
          ref.read(cryptoServiceProvider).hashString(adminId2);
      var adminUser = User(
        userId1: adminId1,
        userId2: hashedAdminId2,
        nickname: nickname, // from new parameter
        firstName: firstName,
        lastName: lastName,
        ordinationName: ordinationName,
        specialTitle: specialTitle,
        phoneNumber: phoneNumber,
        email: email,
        // profileImage will be handled here
        profileImage: null, // Placeholder for now

        role: UserRole.Admin,
        createdAt: DateTime.now(),
      );

      // 3. Initialize the entire database with the first admin user and temple account
      // This new method in DatabaseHelper will handle everything in a single transaction.
      await _dbHelper.initializeNewDatabaseWithAdmin(
          adminUser: adminUser, templeName: templeName);

      // 4. NOW that the DB is created, fetch the newly created user to get their ID.
      final newlyCreatedUser = await _dbHelper.getUserByUserId1(adminId1);
      // We assert that newlyCreatedUser is not null because we just created it.
      // This resolves the unnecessary_null_comparison lint.
      final newAdminId = newlyCreatedUser!.id!;

      // If a logo is provided, save it using the centralized homeStyleProvider.
      if (logoImageFile != null) {
        await ref
            .read(homeStyleProvider.notifier)
            .updateAndSaveStyle(imageFile: logoImageFile);
      }

      // Invalidate providers to force UI refresh
      ref.invalidate(templeNameProvider);
      ref.invalidate(allAccountsProvider);

      // 5. Set user object with new ID
      adminUser = adminUser.copyWith(id: newAdminId);

      // 6. Save PIN and log in
      await _secureStorage.savePin(pin);
      await _secureStorage.saveLastUserId(newAdminId);

      // 7. Update state to loggedIn
      state = state.copyWith(
        status: AuthStatus.loggedIn,
        user: adminUser,
        errorMessage: null,
      );
      return adminId2; // Return the generated ID2 on success
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.loggedOut,
        errorMessage: 'เกิดข้อผิดพลาดในการสร้างบัญชีผู้ดูแล',
      );
      return null; // Return null on failure
    }
  }

  /// Handles the database file import process.
  Future<bool> importDatabaseFile() async {
    File? tempFile;
    try {
      // 1. Pick the file
      final result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result == null || result.files.single.path == null) {
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
      final timestampKey =
          match.group(1)!.replaceAll('_', ''); // Key is yyyyMMddHHmm

      final cryptoService = ref.read(cryptoServiceProvider);
      final decryptedJsonBytes = cryptoService.decryptData(
        encryptedBytes,
        timestampKey,
      );

      // Decode the JSON and validate the Temple ID
      final jsonString = utf8.decode(decryptedJsonBytes);
      final importData = jsonDecode(jsonString);
      final importMetadata = importData['metadata'];
      final importTempleId = importMetadata['temple_id'];

      final currentTempleId = await _dbHelper.getAppMetadata('temple_id');

      // This is the crucial check. If the app has a temple ID, it must match the file's ID.
      if (currentTempleId != null && importTempleId != currentTempleId) {
        throw Exception('ไฟล์สำรองข้อมูลนี้เป็นของวัดอื่น ไม่สามารถนำเข้าได้');
      }

      // 4. Define paths and write decrypted data to a temporary file for validation
      final dbDirectoryPath = await getDatabasesPath();
      final appDbPath = p.join(dbDirectoryPath, 'temple_funds.db');
      final tempDbPath = p.join(dbDirectoryPath, 'import_temp.db');
      tempFile = File(tempDbPath);
      await tempFile.writeAsBytes(base64Decode(importData['data']));

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

      // Invalidate the provider so the UI re-fetches the temple name from the new DB.
      ref.invalidate(templeNameProvider);

      // 7. Reset the auth state completely.
      await logout();
      return true;
    } catch (e) {
      final errorString = e.toString();
      // Check for common decryption error messages
      if (errorString.contains(
            'Invalid argument(s): Invalid or corrupted pad block',
          ) ||
          errorString.contains('bad padding')) {
        state = state.copyWith(
          errorMessage:
              'นำเข้าไฟล์ไม่สำเร็จ: รหัสผ่านไม่ถูกต้อง หรือไฟล์เสียหาย',
        );
      } else {
        state = state.copyWith(
          errorMessage:
              'นำเข้าไฟล์ไม่สำเร็จ: ${errorString.replaceFirst("Exception: ", "")}',
        );
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

  /// Allows the user to go back from the PIN screen to the Welcome screen.
  Future<void> goBackToWelcomeScreen() async {
    // This resets the auth flow state but keeps the PIN and last user ID stored.
    // So if the user closes the app and re-opens, it will ask for PIN again.
    state = AuthState(
      status: AuthStatus.loggedOut,
      user: null, // Clear the partially logged-in user
      errorMessage: null,
      lockoutUntil: null,
      lastDbExport: state.lastDbExport,
    );
  }

  /// Resets the entire application to its initial state by deleting the database and PIN.
  Future<void> resetApp() async {
    await _secureStorage.deleteAll();
    await _dbHelper.deleteDatabaseFile();
    state = AuthState(
      status: AuthStatus.loggedOut,
    ); // Reset to a clean loggedOut state
  }

  /// Saves the timestamp of the last successful DB export.
  Future<void> saveLastDbExportTimestamp(DateTime timestamp) async {
    await _secureStorage.saveLastDbExportTimestamp(timestamp);
    state = state.copyWith(lastDbExport: timestamp); // Update state
  }

  Future<void> logout() async {
    // FIX: Use `deleteAuthCredentials` to only remove PIN and user ID,
    // preserving other settings like logo size which are also in secure storage.
    await _secureStorage.deleteAuthCredentials();
    // After deleting credentials, simply reset the state to loggedOut.
    // The AuthWrapper will then show the appropriate screen (WelcomeScreen or LoginScreen)
    // on the next app start, which is the correct behavior.
    state = AuthState(status: AuthStatus.loggedOut);
  }

  /// Clears any existing error message from the state.
  void clearError() {
    if (state.errorMessage != null || state.lockoutUntil != null) {
      state = state.copyWith(errorMessage: null, lockoutUntil: null);
    }
  }
}

// Part 4: Define the provider itself
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
