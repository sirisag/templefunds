import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:templefunds/core/utils/date_formatter.dart';

class TransactionConfirmationDetails extends StatelessWidget {
  final String transactionType;
  final double amount;
  final String description;
  final DateTime date;
  final List<String> accountNames;

  const TransactionConfirmationDetails({
    super.key,
    required this.transactionType,
    required this.amount,
    required this.description,
    required this.date,
    required this.accountNames,
  });

  @override
  Widget build(BuildContext context) {
    final typeText = transactionType == 'income' ? 'รายรับ' : 'รายจ่าย';
    final dateText =
        DateFormatter.formatBE(date.toLocal(), 'd MMM yyyy, HH:mm');
    final amountText = NumberFormat("#,##0.00").format(amount);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'กรุณาตรวจสอบข้อมูลก่อนบันทึก:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Text('ประเภท: $typeText'),
          Text(
            'จำนวนเงิน${accountNames.length > 1 ? ' (ต่อบัญชี)' : ''}: ฿$amountText',
          ),
          Text('คำอธิบาย: $description'),
          Text('วันที่: $dateText'),
          if (accountNames.isNotEmpty) ...[
            const Divider(),
            Text(
              'สำหรับ ${accountNames.length} บัญชี:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Display list of selected accounts
            ...accountNames.map(
              (name) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(' • $name'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
