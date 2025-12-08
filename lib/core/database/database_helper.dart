import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account_model.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  // Static properties to hold initial data for the very first creation.
  // This is a workaround to pass data into the `_onCreate` callback.
  static User? _initialAdminUser;
  static String? _initialTempleName;

  // Getter for the database. If it doesn't exist, it will be initialized.
  Future<Database> get database async {
    // If database is not null and is open, return it. Otherwise, initialize it.
    if (_database != null && _database!.isOpen) return _database!;
    // Pass the static variables to _initDB. If they are null (normal operation),
    // _initDB will handle it. This ensures that during the first creation,
    // the data is passed correctly.
    _database = await _initDB(
        initialAdmin: _initialAdminUser, initialTempleName: _initialTempleName);
    return _database!;
  }

  // --- Database Initialization ---

  /// Initializes the database. If this is the first time, it uses the static
  /// properties `_initialAdminUser` and `_initialTempleName` within `_onCreate`.
  Future<Database> _initDB(
      {User? initialAdmin, String? initialTempleName}) async {
    // Store the initial data in static variables before opening the database.
    if (initialAdmin != null && initialTempleName != null) {
      _initialAdminUser = initialAdmin;
      _initialTempleName = initialTempleName;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'temple_funds.db');

    return await openDatabase(
      path,
      version: 2, // Incremented version
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE transactions ADD COLUMN remark TEXT;");
      await db
          .execute("ALTER TABLE transactions ADD COLUMN receipt_image TEXT;");
    }
  }

  /// This method is called only when the database is created for the first time.
  /// It creates all the necessary tables.
  Future<void> _onCreate(Database db, int version) async {
    // Using Batch to execute multiple statements in one go for efficiency.
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id_1 TEXT NOT NULL UNIQUE,
        user_id_2 TEXT NOT NULL,
        first_name TEXT,
        last_name TEXT,
        nickname TEXT NOT NULL,
        ordination_name TEXT,
        special_title TEXT,
        phone_number TEXT,
        email TEXT,
        profile_image TEXT,
        role TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active'
      )
    ''');

    batch.execute('''
      CREATE TABLE recovery_codes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        code TEXT NOT NULL UNIQUE,
        is_used INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        is_tagged INTEGER NOT NULL DEFAULT 0,
        used_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        owner_user_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE SET NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        account_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        remark TEXT,
        receipt_image TEXT,
        transaction_date TEXT NOT NULL,
        created_by_user_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
        FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE NO ACTION
      )
    ''');

    batch.execute('''
      CREATE TABLE app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await batch.commit(noResult: true);

    // After creating tables, if we have initial data, insert it now.
    if (_initialAdminUser != null && _initialTempleName != null) {
      // Insert Admin User
      await db.insert('users', _initialAdminUser!.toMap());

      // Create and Insert Temple Account
      final templeAccount = Account(
        name: 'กองกลางวัด',
        ownerUserId: null, // No specific owner
        createdAt: DateTime.now(),
      );
      await db.insert('accounts', templeAccount.toMap());

      // Set Temple Name
      await db.insert(
          'app_metadata', {'key': 'temple_name', 'value': _initialTempleName!});

      // Clean up static variables
      _initialAdminUser = null;
      _initialTempleName = null;
    }
  }

  /// Deletes the entire database file from the device.
  Future<void> deleteDatabaseFile() async {
    // First, ensure the database is closed to release any file locks.
    await close();
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'temple_funds.db');
    if (await databaseExists(path)) {
      await deleteDatabase(path);
    }
  }

  /// Validates that the database at the given path has the required table structure.
  /// Throws an exception if validation fails.
  Future<void> validateDatabaseFile(String path) async {
    Database? db;
    try {
      db = await openDatabase(path, readOnly: true);
      const requiredTables = {
        'users',
        'accounts',
        'transactions',
        'recovery_codes',
        'app_metadata'
      };
      final tablesResult = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final existingTables =
          tablesResult.map((row) => row['name'] as String).toSet();

      final missingTables = requiredTables.difference(existingTables);

      if (missingTables.isNotEmpty) {
        throw Exception(
            'ไฟล์ข้อมูลไม่ถูกต้อง (ขาดตาราง: ${missingTables.join(', ')})');
      }
    } catch (e) {
      // Re-throw our specific exception or a more generic one if it's not ours.
      if (e.toString().contains('ขาดตาราง')) rethrow;
      throw Exception(
          'ไม่สามารถเปิดไฟล์ข้อมูลได้ อาจเป็นไฟล์ที่เสียหายหรือไม่ใช่ไฟล์ฐานข้อมูล');
    } finally {
      await db?.close();
    }
  }

  // --- CRUD Methods for 'app_metadata' table ---

  /// Sets a key-value pair in the metadata table.
  Future<void> setAppMetadata(String key, String value) async {
    final db = await instance.database;
    await db.insert(
      'app_metadata',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves a value from the metadata table by its key.
  Future<String?> getAppMetadata(String key) async {
    final db = await instance.database;
    final result = await db.query('app_metadata',
        where: 'key = ?', whereArgs: [key], limit: 1);
    if (result.isNotEmpty) {
      return result.first['value'] as String?;
    }
    return null;
  }

  /// Fetches the timestamp of the most recent transaction.
  /// Returns null if there are no transactions.
  Future<DateTime?> getLatestTransactionTimestamp() async {
    final db = await database;
    // Use a try-catch block in case the database is empty or doesn't exist yet.
    try {
      final result = await db.query('transactions',
          orderBy: 'createdAt DESC', limit: 1, columns: ['createdAt']);
      if (result.isNotEmpty) {
        return DateTime.parse(result.first['createdAt'] as String);
      }
    } catch (e) {
      return null; // Table might not exist, or other errors.
    }
    return null;
  }

  // --- CRUD Methods for 'accounts' table ---

  /// Inserts a new account.
  Future<int> addAccount(Account account) async {
    final db = await instance.database;
    return await db.insert('accounts', account.toMap());
  }

  /// Retrieves all accounts from the database.
  Future<List<Account>> getAllAccounts() async {
    final db = await instance.database;
    final maps = await db.query('accounts', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Account.fromMap(maps[i]));
  }

  /// Initializes a brand new database, creating the admin user, temple account,
  /// and setting the temple name, all within a single atomic transaction.
  /// This is called only during the very first registration.
  Future<void> initializeNewDatabaseWithAdmin({
    required User adminUser,
    required String templeName,
  }) async {
    // This method now only triggers the database initialization.
    // The actual creation logic is inside `_onCreate` which is called by `_initDB`.
    _initialAdminUser = adminUser;
    _initialTempleName = templeName;
    // Close any existing connection and nullify the instance.
    await instance.close();
    // By calling the getter, it will re-initialize the database using _initDB
    // which will then use the static variables we just set.
    await instance.database;
  }

  /// Adds multiple transactions in a single atomic batch operation.
  /// This is much more efficient than adding them one by one.
  Future<void> addMultipleTransactionsInBatch(
      List<Transaction> transactions) async {
    final db = await instance.database; // สมมติว่าคุณมี getter 'database'
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final transaction in transactions) {
        // สมมติว่าชื่อตารางคือ 'transactions' และ model มีเมธอด toMap()
        batch.insert('transactions', transaction.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // noResult: true จะมีประสิทธิภาพสูงกว่าเล็กน้อย
      await batch.commit(noResult: true);
    });
  }

  /// Adds a new user and their corresponding personal account within a single database transaction.
  /// This ensures data integrity, as both operations will either succeed or fail together.
  Future<void> addUserWithAccount(User user, Account account) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Insert the user and get their new ID.
      final newUserId = await txn.insert(
        'users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Create a new account object with the owner ID set to the new user's ID.
      final accountWithOwner = account.copyWith(ownerUserId: newUserId);

      // Insert the account.
      await txn.insert('accounts', accountWithOwner.toMap());
    });
  }

  // --- CRUD Methods for 'users' table ---

  /// Inserts a new user. If this is the first user (Admin during registration),
  /// it ensures the database is fully created first.
  Future<int> addUser(User user) async {
    final db = await instance.database;

    // Check if this is the very first user being added.
    // The `users` table is one of the first to be created.
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='users'");
    if (tables.isEmpty) {
      // This should not happen if _onCreate was called, but as a safeguard,
      // we can manually trigger the creation logic if needed.
      // However, the main fix is ensuring _initDB is awaited properly.
      // The primary purpose of this check is to understand the state.
    }

    return await db.insert('users', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Retrieves a user by their primary key ID.
  Future<User?> getUserById(int id) async {
    final db = await instance.database;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  /// Retrieves a user by their custom user_id_1. Useful for login.
  Future<User?> getUserByUserId1(String userId1) async {
    final db = await instance.database;
    final maps =
        await db.query('users', where: 'user_id_1 = ?', whereArgs: [userId1]);
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  /// Checks if a user_id_1 already exists in the database.
  Future<bool> checkIfUserId1Exists(String userId1) async {
    final db = await instance.database;
    final result = await db.query(
      'users',
      where: 'user_id_1 = ?',
      whereArgs: [userId1],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Checks if a nickname already exists in the database.
  Future<bool> checkIfNicknameExists(String nickname) async {
    final db = await instance.database;
    final result = await db.query(
      'users',
      where: 'nickname = ?',
      whereArgs: [nickname],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Retrieves all users from the database, ordered by nickname.
  Future<List<User>> getAllUsers() async {
    final db = await instance.database;
    // Order by role first (Admin, Master, Monk), then by nickname
    final maps = await db.query('users', orderBy: '''
      CASE role
        WHEN 'Admin' THEN 0
        WHEN 'Master' THEN 1
        ELSE 2
      END, nickname ASC
    ''');
    return List.generate(maps.length, (i) {
      return User.fromMap(maps[i]);
    });
  }

  /// Updates an existing user.
  Future<int> updateUser(User user) async {
    final db = await instance.database;
    return await db
        .update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  /// Deletes a user by their primary key ID.
  Future<int> deleteUser(int id) async {
    final db = await instance.database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  /// Updates only the status of a specific user.
  Future<int> updateUserStatus(int id, String newStatus) async {
    final db = await instance.database;
    return await db.update('users', {'status': newStatus},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Updates only the role of a specific user.
  Future<int> updateUserRole(int id, String newRole) async {
    final db = await instance.database;
    return await db.update('users', {'role': newRole},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Updates the profile information of a specific user.
  Future<int> updateUserProfile(int id, User user) async {
    final db = await instance.database;
    // Only update the fields that are part of the user profile
    // We exclude id, user_id_2, and created_at as they should not be changed here.
    // user_id_1 is also excluded as per the new requirement.
    final dataToUpdate = user.toMap();
    dataToUpdate.remove('id');
    dataToUpdate.remove('user_id_2');
    dataToUpdate.remove('created_at');
    // dataToUpdate.remove('user_id_1'); // user_id_1 is already excluded from copyWith in the screen

    return await db
        .update('users', dataToUpdate, where: 'id = ?', whereArgs: [id]);
  }

  /// Updates only the user_id_2 of a specific user.
  Future<int> updateUserId2(int id, String newId2) async {
    final db = await instance.database;
    return await db.update(
      'users',
      {'user_id_2': newId2},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- CRUD Methods for 'recovery_codes' table ---

  /// Fetches all recovery codes for a specific user.
  Future<List<Map<String, dynamic>>> getRecoveryCodesForUser(int userId) async {
    final db = await instance.database;
    return await db.query('recovery_codes',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
  }

  /// Adds a new recovery code to the database.
  Future<void> addRecoveryCode(
      int userId, String code, DateTime createdAt) async {
    final db = await instance.database;
    await db.insert('recovery_codes', {
      'user_id': userId,
      'code': code,
      'is_used': 0,
      'created_at': createdAt.toIso8601String(),
    });
  }

  /// Finds a specific, unused recovery code for a user.
  Future<Map<String, dynamic>?> findUnusedRecoveryCode(
      int userId, String code) async {
    final db = await instance.database;
    final result = await db.query('recovery_codes',
        where: 'user_id = ? AND code = ? AND is_used = 0',
        whereArgs: [userId, code],
        limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  /// Marks a recovery code as used.
  Future<void> markRecoveryCodeAsUsed(int codeId) async {
    final db = await instance.database;
    await db.update('recovery_codes',
        {'is_used': 1, 'used_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [codeId]);
  }

  /// Toggles the 'is_tagged' status of a specific recovery code.
  Future<void> toggleRecoveryCodeTag(int codeId, bool isCurrentlyTagged) async {
    final db = await instance.database;
    await db.update(
      'recovery_codes',
      {'is_tagged': isCurrentlyTagged ? 0 : 1},
      where: 'id = ?',
      whereArgs: [codeId],
    );
  }

  /// Marks all unused recovery codes for a user as used.
  /// This is useful when generating a completely new set of codes.
  Future<void> invalidateAllUnusedRecoveryCodes(int userId) async {
    final db = await instance.database;
    await db.update(
      'recovery_codes',
      {'is_used': 1, 'used_at': DateTime.now().toIso8601String()},
      where: 'user_id = ? AND is_used = 0',
      whereArgs: [userId],
    );
  }

  /// Deletes specific recovery codes by their IDs.
  /// Used to trim excess codes.
  Future<void> deleteRecoveryCodes(List<int> codeIds) async {
    if (codeIds.isEmpty) return;
    final db = await instance.database;
    final args = List.filled(codeIds.length, '?').join(',');
    await db.delete('recovery_codes',
        where: 'id IN ($args)', whereArgs: codeIds);
  }

  // --- CRUD Methods for 'transactions' table ---

  /// Inserts a new transaction.
  Future<void> addTransaction(Transaction transaction) async {
    final db = await instance.database;
    await db.insert('transactions', transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Retrieves all transactions, ordered by date descending.
  Future<List<Transaction>> getAllTransactions() async {
    final db = await instance.database;
    // Changed to ASC to sort from oldest to newest by default
    final maps =
        await db.query('transactions', orderBy: 'transaction_date ASC');
    return List.generate(maps.length, (i) {
      return Transaction.fromMap(maps[i]);
    });
  }

  /// Retrieves transactions for a specific account.
  Future<List<Transaction>> getTransactionsForAccount(int accountId) async {
    final db = await instance.database;
    final maps = await db.query(
      'transactions',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'transaction_date ASC',
    );
    return List.generate(maps.length, (i) {
      return Transaction.fromMap(maps[i]);
    });
  }

  /// Deletes a transaction by its ID (UUID).
  Future<int> deleteTransaction(String id) async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// Closes the database connection.
  Future<void> close() async {
    // Only try to close if the database instance exists and is open.
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database =
          null; // Set to null so it can be re-initialized on next access.
    }
  }
}

/// Provider for the DatabaseHelper instance.
final databaseHelperProvider = Provider((ref) => DatabaseHelper.instance);
