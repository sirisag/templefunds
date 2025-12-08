import 'dart:io';
import 'dart:convert';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/secure_storage_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/crypto_service.dart';
import '../../transactions/providers/accounts_provider.dart';
import '../../recovery/providers/recovery_codes_provider.dart';
import '../../members/providers/members_provider.dart';
import '../../transactions/providers/transactions_provider.dart';
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
  final DateTime? lastDbExport;
  final DateTime? lockoutUntil; // New: To track lockout time across the app

  AuthState({
    this.status = AuthStatus.initializing,
    this.user,
    this.lastDbExport,
    this.lockoutUntil,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    DateTime? lastDbExport,
    DateTime? lockoutUntil,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user, // Allow clearing the error message
      lastDbExport: lastDbExport ?? this.lastDbExport,
      lockoutUntil: lockoutUntil ?? this.lockoutUntil,
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
    final lockoutTime = await _secureStorage.getLockoutEndTime();
    if (lockoutTime != null && lockoutTime.isAfter(DateTime.now())) {
      debugPrint("[Auth] User is currently locked out. Initialization halted.");
      // Set the lockout time in the state so the UI can react.
      state = state.copyWith(lockoutUntil: lockoutTime);
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
          debugPrint(
              "[Auth] DB exists, but no user saved. Setting state to loggedOut.");
          // Set to loggedOut to show the WelcomeScreen first.
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
          status: AuthStatus
              .loggedOut); // No error reporting here, as UI is not ready
    }
    debugPrint("[Auth] Initialization complete. Final status: ${state.status}");
  }

  /// Checks if the user is currently locked out and updates the state if so.
  /// Returns true if locked out, false otherwise.
  Future<bool> _isCurrentlyLockedOut() async {
    final lockoutTime = await _secureStorage.getLockoutEndTime();
    final isLocked = lockoutTime != null && lockoutTime.isAfter(DateTime.now());
    if (isLocked) {
      state = state.copyWith(lockoutUntil: lockoutTime);
      return true;
    }
    return false;
  }

  /// Handles the logic for a failed login attempt.
  Future<(String, DateTime?)> _handleLoginFailure(
      {required String baseErrorMessage}) async {
    final newFailureCount = await _secureStorage.incrementLoginFailureCount();
    const lockoutThreshold = 4;

    String errorMessage;
    DateTime? lockoutEndTime;
    if (newFailureCount >= lockoutThreshold) {
      // New: Exponential backoff for lockout duration.
      // It starts at 15 seconds and doubles with each subsequent failure.
      // The number of lockouts that have occurred is `newFailureCount - lockoutThreshold`.
      final lockoutCount = newFailureCount - lockoutThreshold;
      final baseLockoutSeconds = 15;
      final lockoutSeconds = baseLockoutSeconds * pow(2, lockoutCount);
      lockoutEndTime = DateTime.now().add(
        Duration(seconds: lockoutSeconds.toInt()),
      );
      await _secureStorage.setLockoutEndTime(lockoutEndTime);
      state = state.copyWith(lockoutUntil: lockoutEndTime); // Update state
      errorMessage = '$baseErrorMessage และถูกล็อกชั่วคราว';
    } else {
      errorMessage = baseErrorMessage;
    }
    return (errorMessage, lockoutEndTime);
  }

  // This would be called from the PIN screen
  Future<void> setPinAndLogin(String pin) async {
    if (state.user?.id == null) return; // Should not happen, but good practice
    await _secureStorage.resetLoginFailureCount(); // Reset on successful setup
    await _secureStorage.savePin(pin);
    state = state.copyWith(lockoutUntil: null); // Clear lockout on success
    await _secureStorage.saveLastUserId(state.user!.id!);
    state = state.copyWith(
      status: AuthStatus.loggedIn,
      user: state.user,
    );
  }

  // This would be called from the PIN screen
  Future<(String, DateTime?)?> loginWithPin(String pin) async {
    if (await _isCurrentlyLockedOut())
      return ('คุณถูกล็อกการใช้งานชั่วคราว', null);

    final isPinCorrect = await _secureStorage.verifyPin(pin);
    if (isPinCorrect) {
      await _secureStorage.resetLoginFailureCount();
      state = state.copyWith(lockoutUntil: null); // Clear lockout on success
      state = state.copyWith(
        status: AuthStatus.loggedIn,
      );
      return null; // Success
    } else {
      return await _handleLoginFailure(baseErrorMessage: 'PIN ไม่ถูกต้อง');
    }
  }

  /// New method for the combined login screen.
  Future<(String, DateTime?)?> loginWithIds(
      {required String id1, required String id2}) async {
    if (await _isCurrentlyLockedOut())
      return ('คุณถูกล็อกการใช้งานชั่วคราว', null);
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
      state = state.copyWith(lockoutUntil: null); // Clear lockout on success
      state = state.copyWith(
        status: AuthStatus.requiresPinSetup,
        user: user,
      );
      return null; // Success
    } catch (e) {
      return await _handleLoginFailure(
        baseErrorMessage: e.toString().replaceFirst("Exception: ", ""),
      );
    }
  }

  /// Recovers an account using a recovery code.
  Future<(String, DateTime?)?> recoverAccount({
    required String userId1,
    required String recoveryCode,
  }) async {
    if (await _isCurrentlyLockedOut())
      return ('คุณถูกล็อกการใช้งานชั่วคราว', null);

    try {
      final user = await _dbHelper.getUserByUserId1(userId1);
      if (user == null) {
        throw Exception('ไม่พบผู้ใช้งานรหัสนี้');
      }

      final foundCode =
          await _dbHelper.findUnusedRecoveryCode(user.id!, recoveryCode);
      if (foundCode == null) {
        throw Exception('รหัสกู้คืนไม่ถูกต้องหรือถูกใช้ไปแล้ว');
      }

      // Credentials are correct
      await _secureStorage.resetLoginFailureCount();
      state = state.copyWith(lockoutUntil: null); // Clear lockout on success

      // Mark the code as used
      await _dbHelper.markRecoveryCodeAsUsed(foundCode['id'] as int);

      // Update state to allow setting a new PIN
      state = state.copyWith(
        status: AuthStatus.requiresPinSetup,
        user: user,
      );
      return null; // Success
    } catch (e) {
      return await _handleLoginFailure(
          baseErrorMessage: e.toString().replaceFirst("Exception: ", ""));
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

      // 5. Generate initial recovery codes for the new admin
      await ref
          .read(recoveryCodesProvider.notifier)
          .regenerateCodes(newAdminId);

      // 6. Save PIN, log in, and update user object in state
      adminUser =
          adminUser.copyWith(id: newAdminId); // Now set user object with new ID
      await _secureStorage.savePin(pin);
      await _secureStorage.saveLastUserId(newAdminId);
      state = state.copyWith(
        status: AuthStatus.loggedIn,
        user: adminUser,
      );
      return adminId2; // Return the generated ID2 on success
    } catch (e) {
      // The error will be caught and returned by the UI layer
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
      if (extension != '.zip') {
        throw Exception('กรุณาเลือกไฟล์สำรองข้อมูล (.zip) เท่านั้น');
      }

      // 2. Read the encrypted file bytes
      final encryptedZipBytes = await File(pickedFilePath).readAsBytes();

      // 3. Decrypt the data
      // Extract the timestamp from the filename to use as the decryption key.
      final match = RegExp(r'_(\d{8}_\d{4})\.zip$').firstMatch(pickedFileName);
      if (match == null || match.group(1) == null) {
        throw Exception('ชื่อไฟล์ไม่ถูกต้อง ไม่สามารถถอดรหัสได้');
      }
      final timestampKey =
          match.group(1)!.replaceAll('_', ''); // Key is yyyyMMddHHmm

      final cryptoService = ref.read(cryptoServiceProvider);
      final decryptedZipBytes = cryptoService.decryptData(
        encryptedZipBytes,
        timestampKey,
      );

      // 4. Decode the ZIP archive from the decrypted bytes
      final archive = ZipDecoder().decodeBytes(decryptedZipBytes);
      final dbJsonFile = archive.findFile('database.json');

      if (dbJsonFile == null) {
        throw Exception('ไฟล์ ZIP ไม่ถูกต้อง (ไม่พบ database.json)');
      }

      // 5. Decode the JSON from the archive and validate the Temple ID
      final dbJsonString = utf8.decode(dbJsonFile.content as List<int>);
      final dbImportData = jsonDecode(dbJsonString);
      final importMetadata = dbImportData['metadata'];
      final importTempleId = importMetadata['temple_id'];

      final currentTempleId = await _dbHelper.getAppMetadata('temple_id');

      if (currentTempleId != null && importTempleId != currentTempleId) {
        throw Exception('ไฟล์สำรองข้อมูลนี้เป็นของวัดอื่น ไม่สามารถนำเข้าได้');
      }

      // New Check: Compare import file's timestamp with the latest data in the current DB.
      final importTimestampString = importMetadata['export_timestamp'];
      if (importTimestampString != null) {
        final importTimestamp = DateTime.parse(importTimestampString);
        final latestTransactionTimestamp =
            await _dbHelper.getLatestTransactionTimestamp();

        // If the current DB has data (latestTransactionTimestamp is not null)
        // and the import file is older than or same as the latest data, throw an error.
        if (latestTransactionTimestamp != null &&
            !importTimestamp.isAfter(latestTransactionTimestamp)) {
          throw Exception(
            'ไฟล์สำรองข้อมูลนี้เก่ากว่าข้อมูลปัจจุบันที่มีอยู่ในเครื่อง ไม่สามารถนำเข้าเพื่อป้องกันข้อมูลสูญหายได้',
          );
        }
      }
      // End of New Check

      // 6. Close existing DB, delete old files (DB and images)
      await _dbHelper.close();
      final appDocsDir = await getApplicationDocumentsDirectory();
      final dbDirectoryPath = await getDatabasesPath();
      final appDbPath = p.join(dbDirectoryPath, 'temple_funds.db');

      // Delete old DB
      final oldDbFile = File(appDbPath);
      if (await oldDbFile.exists()) {
        await oldDbFile.delete();
      }
      // Delete old images directory
      final imageDir = Directory(p.join(appDocsDir.path));
      if (await imageDir.exists()) {
        await imageDir.delete(recursive: true);
      }
      await imageDir.create(recursive: true); // Recreate the base directory

      // 7. Write new DB data to a temporary file for validation
      final tempDbPath = p.join(dbDirectoryPath, 'import_temp.db');
      tempFile = File(tempDbPath);
      await tempFile.writeAsBytes(base64Decode(dbImportData['data']));

      // 8. Validate the structure of the temporary database file
      await _dbHelper.validateDatabaseFile(tempDbPath);

      // 9. If validation is successful, replace the old DB
      // Close connection again before renaming to release file lock on temp file.
      await _dbHelper.close();

      // Rename the validated temp file to be the main DB.
      await tempFile.rename(appDbPath);
      tempFile = null; // Prevent deletion in the finally block.

      // 8. Extract and write all image files from the archive
      for (final file in archive.files) {
        if (file.name.startsWith('images/')) {
          final filename = p.relative(file.name, from: 'images/');
          final newImagePath = p.join(appDocsDir.path, filename);
          final newImageFile = File(newImagePath);
          await newImageFile.create(recursive: true);
          await newImageFile.writeAsBytes(file.content as List<int>);
        }
      }

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
        throw Exception(
            'นำเข้าไฟล์ไม่สำเร็จ: รหัสผ่านไม่ถูกต้อง หรือไฟล์เสียหาย');
      } else {
        throw Exception(
            'นำเข้าไฟล์ไม่สำเร็จ: ${errorString.replaceFirst("Exception: ", "")}');
      }
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
      lastDbExport: state.lastDbExport,
    );
  }

  /// Resets the entire application to its initial state by deleting the database and PIN.
  Future<void> resetApp() async {
    // 1. Delete all secure storage data (PIN, user ID, etc.)
    await _secureStorage.deleteAll();

    // 2. Delete the database file
    await _dbHelper.deleteDatabaseFile();

    // 3. Clear all SharedPreferences data (theme, custom images, font size, etc.)
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 4. Delete all user-generated files (images, logos, etc.)
    // This ensures a complete reset by removing all files from the app's documents directory.
    final appDocsDir = await getApplicationDocumentsDirectory();
    if (await appDocsDir.exists()) {
      // Delete the directory and all its contents, then recreate it empty.
      await appDocsDir.delete(recursive: true);
      await appDocsDir.create(recursive: true);
    }

    // 4. Reset the authentication state in memory
    state = AuthState(
      status: AuthStatus.loggedOut, // Reset to a clean loggedOut state
    );

    // Invalidate all major data providers to force a full refresh across the app.
    // This ensures that any cached data from the old database is cleared.
    ref.invalidate(membersProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(allAccountsProvider);
    ref.invalidate(recoveryCodesProvider);
    ref.invalidate(templeNameProvider);
    ref.invalidate(homeStyleProvider);
    ref.invalidate(backgroundStyleProvider);
  }

  /// Saves the timestamp of the last successful DB export.
  Future<void> saveLastDbExportTimestamp(DateTime timestamp) async {
    await _secureStorage.saveLastDbExportTimestamp(timestamp);
    state = state.copyWith(lastDbExport: timestamp); // Update state
  }

  Future<void> logout() async {
    // Use `deleteAuthCredentials` to only remove PIN and user ID,
    // preserving other settings like logo size which are also in secure storage.
    await _secureStorage.deleteAuthCredentials();
    // After deleting credentials, reset the state to loggedOut and clear user/lockout info.
    state =
        AuthState(status: AuthStatus.loggedOut, user: null, lockoutUntil: null);
  }
}

// Part 4: Define the provider itself
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
