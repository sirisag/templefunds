import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:templefunds/features/transactions/widgets/transaction_confirmation_details.dart';

/// Shows a confirmation dialog for a transaction.
/// Returns `true` if confirmed, `false` otherwise.
Future<bool> showTransactionConfirmationDialog({
  required BuildContext context,
  required String transactionType,
  required double amount,
  required String description,
  required DateTime date,
  required List<String> accountNames,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('ยืนยันการบันทึก'),
      content: TransactionConfirmationDetails(
        transactionType: transactionType,
        amount: amount,
        description: description,
        date: date,
        accountNames: accountNames,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('แก้ไข'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('ยืนยัน'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Shows an overdraft warning dialog.
/// Returns `true` if the user chooses to proceed, `false` otherwise.
Future<bool> showOverdraftWarningDialog({
  required BuildContext context,
  required double amount,
  required String accountNames, // Can be a single name or a list
}) async {
  final continueAnyway = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('คำเตือน: ยอดเงินไม่เพียงพอ'),
      content: SingleChildScrollView(
        child: Text(
          'การถอนเงินจำนวน ${NumberFormat("#,##0.00").format(amount)} ฿ จะทำให้บัญชีต่อไปนี้มียอดติดลบ:\n\n • $accountNames\n\nคุณต้องการดำเนินการต่อหรือไม่?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('อนุมัติยอดติดลบ'),
        ),
      ],
    ),
  );
  return continueAnyway ?? false;
}
