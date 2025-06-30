import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/account_model.dart';
import '../models/user_model.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  // Getter for the database. If it doesn't exist, it will be initialized.
  Future<Database> get database async {
    // If database is not null and is open, return it. Otherwise, initialize it.
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDB();
    return _database!;
  }

  // --- Database Initialization ---

  /// Initializes the database by opening it or creating it if it doesn't exist.
  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'temple_funds.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
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


  /// This method is called only when the database is created for the first time.
  /// It creates all the necessary tables.
  Future<void> _onCreate(Database db, int version) async {
    // Using Batch to execute multiple statements in one go for efficiency.
    final batch = db.batch();
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id_1 TEXT NOT NULL UNIQUE,
        user_id_2 TEXT NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active'
      )
    ''');

    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        owner_user_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        account_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        transaction_date TEXT NOT NULL,
        created_by_user_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
        FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE NO ACTION
      )
    ''');

    await db.execute('''
      CREATE TABLE app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await batch.commit(noResult: true);
  }

  // --- Transactional Operations ---

  /// Creates a new member and their personal account within a single transaction.
  /// This ensures that both operations succeed or both fail, maintaining data integrity.
  Future<void> createNewMemberWithAccount(User newUser, Account newAccount) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Step 1: Insert the new user.
      final newUserId = await txn.insert('users', newUser.toMap());

      // Step 2: Create the account for this new user.
      // We use the ID returned from the first insert as the owner_user_id.
      final accountMap = newAccount.toMap();
      accountMap['owner_user_id'] = newUserId;

      await txn.insert('accounts', accountMap);
    });
  }

  // --- CRUD Methods for 'users' table ---

  /// Inserts a new user into the database.
  Future<int> addUser(User user) async {
    final db = await instance.database;
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
    final maps = await db.query('users', where: 'user_id_1 = ?', whereArgs: [userId1]);
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

  /// Checks if a name already exists in the database.
  Future<bool> checkIfNameExists(String name) async {
    final db = await instance.database;
    final result =
        await db.query('users', where: 'name = ?', whereArgs: [name], limit: 1);
    return result.isNotEmpty;
  }

  /// Retrieves all users from the database, ordered by name.
  Future<List<User>> getAllUsers() async {
    final db = await instance.database;
    final maps = await db.query('users', orderBy: 'name ASC');
    return List.generate(maps.length, (i) {
      return User.fromMap(maps[i]);
    });
  }

  /// Updates an existing user.
  Future<int> updateUser(User user) async {
    final db = await instance.database;
    return await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
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
    return await db
        .update('users', {'role': newRole}, where: 'id = ?', whereArgs: [id]);
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

  /// Closes the database connection.
  Future<void> close() async {
    // Only try to close if the database instance exists and is open.
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null; // Set to null so it can be re-initialized on next access.
    }
  }
}