import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:templefunds/core/utils/date_formatter.dart';

class TransactionConfirmationDetails extends StatelessWidget {
  final String transactionType;
  final double amount;
  final String description;
  final String? remark;
  final DateTime date;
  final List<String> accountNames;

  const TransactionConfirmationDetails({
    super.key,
    required this.transactionType,
    required this.amount,
    required this.description,
    this.remark,
    required this.date,
    required this.accountNames,
  });

  @override
  Widget build(BuildContext context) {
    final bool isIncome = transactionType == 'income';
    final typeText = transactionType == 'income' ? 'รายรับ' : 'รายจ่าย';
    final dateText =
        DateFormatter.formatBE(date.toLocal(), 'd MMM yyyy, HH:mm');
    final amountText = NumberFormat("#,##0.00").format(amount);

    final incomeColor = Colors.green.shade700;
    final expenseColor = Colors.red.shade700;
    final descriptionColor = Colors.blue.shade800;

    final amountColor = isIncome ? incomeColor : expenseColor;
    final defaultStyle =
        Theme.of(context).textTheme.bodyLarge ?? const TextStyle();

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'กรุณาตรวจสอบข้อมูลก่อนบันทึก:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const Divider(),
          _buildRichText(
            'ประเภท: ',
            typeText,
            isIncome ? incomeColor : expenseColor,
            defaultStyle,
          ),
          const SizedBox(height: 4),
          _buildRichText(
            'จำนวนเงิน${accountNames.length > 1 ? ' (ต่อบัญชี)' : ''}: ',
            '฿$amountText',
            amountColor,
            defaultStyle,
          ),
          const SizedBox(height: 4),
          _buildRichText(
            'คำอธิบาย: ',
            description,
            descriptionColor,
            defaultStyle,
          ),
          const SizedBox(height: 4),
          if (remark?.isNotEmpty ?? false) ...[
            _buildRichText(
              'หมายเหตุ: ',
              remark!,
              defaultStyle.color, // Use default color
              defaultStyle,
            ),
            const SizedBox(height: 4),
          ],
          _buildRichText(
            'วันที่: ',
            dateText,
            defaultStyle.color, // Use default color
            defaultStyle,
          ),
          if (accountNames.isNotEmpty) ...[
            const Divider(),
            Text(
              'สำหรับ ${accountNames.length} บัญชี:',
              style: defaultStyle.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...accountNames.map(
              (name) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(' • $name', style: defaultStyle),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRichText(
      String label, String value, Color? valueColor, TextStyle defaultStyle) {
    return Text.rich(
      TextSpan(
        text: label,
        style: defaultStyle,
        children: [
          TextSpan(
            text: value,
            style: defaultStyle.copyWith(
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
