import 'package:flutter_test/flutter_test.dart';
import 'package:templefunds/core/models/account_model.dart';
import 'package:templefunds/core/models/transaction_model.dart';
import 'package:templefunds/core/models/user_model.dart';
import 'package:templefunds/features/transactions/utils/account_sorter.dart';

void main() {
  // group ใช้สำหรับจัดกลุ่ม Test Case ที่เกี่ยวข้องกัน
  group('sortAccountsForTransaction', () {
    // สร้างข้อมูลจำลองสำหรับใช้ในการทดสอบ
    final now = DateTime.now();

    // ผู้ใช้
    final masterUser = User(
        id: 1,
        userId1: '0001',
        userId2: 'hash',
        nickname: 'เจ้าอาวาส',
        role: UserRole.Master,
        createdAt: now);
    final monkA = User(
        id: 2,
        userId1: '0002',
        userId2: 'hash',
        nickname: 'พระ A',
        role: UserRole.Monk,
        createdAt: now);
    final monkB = User(
        id: 3,
        userId1: '0003',
        userId2: 'hash',
        nickname: 'พระ B',
        role: UserRole.Monk,
        createdAt: now);
    final monkC = User(
        id: 4,
        userId1: '0004',
        userId2: 'hash',
        nickname: 'พระ C',
        role: UserRole.Monk,
        createdAt: now);

    final allUsers = [masterUser, monkA, monkB, monkC];

    // บัญชี
    final templeAccount =
        Account(id: 10, name: 'กองกลางวัด', createdAt: now, ownerUserId: null);
    final masterAccount = Account(
        id: 11,
        name: 'ปัจจัยเจ้าอาวาส',
        createdAt: now,
        ownerUserId: masterUser.id);
    final monkAAccount = Account(
        id: 12, name: 'ปัจจัยพระ A', createdAt: now, ownerUserId: monkA.id);
    final monkBAccount = Account(
        id: 13, name: 'ปัจจัยพระ B', createdAt: now, ownerUserId: monkB.id);
    final monkCAccount = Account(
        id: 14, name: 'ปัจจัยพระ C', createdAt: now, ownerUserId: monkC.id);

    final allAccounts = [
      monkCAccount, // จงใจใส่ลำดับมั่วๆ
      templeAccount,
      monkAAccount,
      masterAccount,
      monkBAccount
    ];

    // ธุรกรรม
    final allTransactions = [
      // พระ B ทำรายการล่าสุด
      Transaction(
          id: 't1',
          accountId: monkBAccount.id!,
          type: 'income',
          amount: 100,
          transactionDate: now.subtract(const Duration(minutes: 5)),
          createdByUserId: 1,
          createdAt: now),
      // พระ A ทำรายการก่อนหน้า
      Transaction(
          id: 't2',
          accountId: monkAAccount.id!,
          type: 'income',
          amount: 100,
          transactionDate: now.subtract(const Duration(hours: 1)),
          createdByUserId: 1,
          createdAt: now),
      // พระ B ทำรายการเก่าๆ
      Transaction(
          id: 't3',
          accountId: monkBAccount.id!,
          type: 'income',
          amount: 50,
          transactionDate: now.subtract(const Duration(days: 1)),
          createdByUserId: 1,
          createdAt: now),
    ]; // พระ C ไม่มีธุรกรรม

    // test คือ Test Case แต่ละอัน
    test(
        'should sort accounts with Temple first, then Master, then by latest transaction, then alphabetically',
        () {
      // 1. Act: เรียกใช้ฟังก์ชันที่เราต้องการทดสอบ
      final sortedAccounts =
          sortAccountsForTransaction(allAccounts, allUsers, allTransactions);

      // 2. Assert: ตรวจสอบว่าผลลัพธ์ที่ได้ถูกต้องตามที่คาดหวังหรือไม่
      // เราคาดหวังลำดับ: วัด -> เจ้าอาวาส -> พระ B (ล่าสุด) -> พระ A -> พระ C (ไม่มีธุรกรรม, เรียงตามชื่อ)
      expect(sortedAccounts.map((a) => a.id).toList(), [
        templeAccount.id,
        masterAccount.id,
        monkBAccount.id, // พระ B มาก่อนเพราะมีธุรกรรมล่าสุด
        monkAAccount.id,
        monkCAccount.id, // พระ C มาท้ายสุดเพราะไม่มีธุรกรรม
      ]);
    });
  });
}
