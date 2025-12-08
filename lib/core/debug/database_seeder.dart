import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/core/database/database_helper.dart';
import 'package:templefunds/core/models/account_model.dart';
import 'package:templefunds/core/models/transaction_model.dart';
import 'package:templefunds/core/models/user_model.dart';
import 'package:templefunds/core/services/crypto_service.dart';
import 'package:templefunds/core/services/secure_storage_service.dart';
import 'package:uuid/uuid.dart';

/// A service class dedicated to seeding the database with mock data for development and testing.
class DatabaseSeeder {
  final Ref _ref;
  final DatabaseHelper _dbHelper;
  final CryptoService _cryptoService;

  DatabaseSeeder(this._ref) // This now correctly accepts a `Ref`
      : _dbHelper = _ref.read(databaseHelperProvider),
        _cryptoService = _ref.read(cryptoServiceProvider);

  /// Wipes the current database and seeds it with a fresh set of mock data.
  Future<void> seedDatabase() async {
    // 1. Wipe all existing data
    await _dbHelper.deleteDatabaseFile();
    await SecureStorageService().deleteAll();

    // 2. Create Admin and Temple
    const adminId1 = '9999';
    const defaultId2 = '1111'; // Default ID2 for all mock users for easy login
    final hashedDefaultId2 = _cryptoService.hashString(defaultId2);

    final adminUser = User(
      userId1: adminId1,
      userId2: hashedDefaultId2,
      nickname: 'ผู้ดูแลระบบ',
      firstName: 'สมชาย',
      lastName: 'ใจดี',
      role: UserRole.Admin,
      createdAt: DateTime.now(),
    );

    await _dbHelper.initializeNewDatabaseWithAdmin(
      adminUser: adminUser,
      templeName: 'วัดป่าจำลอง',
    );

    // 3. Create Mock Users (Master and Monks)
    final masterUser = User(
      userId1: '0001',
      userId2: hashedDefaultId2,
      nickname: 'หลวงพ่อ',
      firstName: 'ประเสริฐ',
      lastName: 'ผลดี',
      specialTitle: 'พระครูวิมล',
      role: UserRole.Master,
      createdAt: DateTime.now(),
    );
    await _dbHelper.addUserWithAccount(masterUser,
        Account(name: 'ปัจจัยส่วนตัว หลวงพ่อ', createdAt: DateTime.now()));

    // Generate 20 mock monks programmatically
    final monkNicknames = [
      'เอก',
      'บอล',
      'เจมส์',
      'นนท์',
      'โอ๊ต',
      'วิน',
      'ตั้ม',
      'ฟลุ๊ค',
      'อาร์ม',
      'เต้',
      'บอย',
      'กอล์ฟ',
      'แบงค์',
      'ท็อป',
      'นัท',
      'ปอนด์',
      'มิกซ์',
      'พงศ์',
      'เดี่ยว',
      'เบส'
    ];

    for (int i = 0; i < monkNicknames.length; i++) {
      final monk = User(
        userId1: (1001 + i).toString(),
        userId2: hashedDefaultId2,
        nickname: 'พระ${monkNicknames[i]}',
        role: UserRole.Monk,
        createdAt: DateTime.now(),
      );
      await _dbHelper.addUserWithAccount(
          monk,
          Account(
              name: 'ปัจจัยส่วนตัว ${monk.nickname}',
              createdAt: DateTime.now()));
    }

    // 4. Fetch all newly created accounts to get their IDs
    final allAccounts = await _dbHelper.getAllAccounts();
    final templeAccount = allAccounts.firstWhere((a) => a.ownerUserId == null,
        orElse: () =>
            throw Exception("Temple account not found after seeding"));
    final memberAccounts =
        allAccounts.where((a) => a.ownerUserId != null).toList();

    // 5. Generate Mock Transactions
    final transactions = <Transaction>[];
    final random = Random();
    final now = DateTime.now();
    const uuid = Uuid();

    // Generate transactions for the last 6 months
    for (int i = 0; i < 180; i++) {
      final date = now.subtract(Duration(days: i));

      // Add 1-3 temple transactions per day
      for (int j = 0; j < random.nextInt(3) + 1; j++) {
        final isIncome = random.nextBool();
        transactions.add(Transaction(
          id: uuid.v4(),
          accountId: templeAccount.id!,
          type: isIncome ? 'income' : 'expense',
          amount: (random.nextInt(5000) + 100).toDouble(),
          description: isIncome ? 'ญาติโยมถวายปัจจัย' : 'ค่าใช้จ่ายวัด',
          remark: isIncome ? 'บริจาคทั่วไป' : 'ค่าไฟ',
          transactionDate: date.subtract(Duration(hours: random.nextInt(12))),
          createdByUserId: 1, // Admin
          createdAt: date,
        ));
      }

      // For each member, add 1 or 2 transactions per day to simulate frequent activity.
      if (memberAccounts.isNotEmpty) {
        for (final account in memberAccounts) {
          // Generate 1 or 2 transactions for this specific member on this day
          for (int k = 0; k < (1 + random.nextInt(2)); k++) {
            final isIncome = random.nextDouble() > 0.3; // 70% chance of income
            transactions.add(Transaction(
              id: uuid.v4(),
              accountId: account.id!,
              type: isIncome ? 'income' : 'expense',
              amount: isIncome
                  ? (random.nextInt(500) + 50).toDouble()
                  : (random.nextInt(200) + 20).toDouble(),
              description: isIncome
                  ? (random.nextBool() ? 'กิจนิมนต์' : 'ญาติโยมถวาย')
                  : (random.nextBool() ? 'ของใช้ส่วนตัว' : 'ค่าเดินทาง'),
              transactionDate: date.subtract(Duration(
                  hours: random.nextInt(20), minutes: random.nextInt(60))),
              createdByUserId: 1, // Admin
              createdAt: date,
            ));
          }
        }
      }
    }

    await _dbHelper.addMultipleTransactionsInBatch(transactions);
  }
}

/// Provider for the DatabaseSeeder service.
final databaseSeederProvider = Provider((ref) => DatabaseSeeder(ref));
