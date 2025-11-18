import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:templefunds/core/utils/date_formatter.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/members/screens/member_management_screen.dart';
import 'package:templefunds/features/transactions/providers/balance_provider.dart';
import 'package:templefunds/features/transactions/screens/add_multi_transaction_screen.dart';

class AdminControlPanel extends ConsumerWidget {
  final Future<void> Function() onExport;

  const AdminControlPanel({super.key, required this.onExport});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastExportDate = ref.watch(authProvider).lastDbExport;
    final balanceSummaryAsync = ref.watch(balanceSummaryProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // First Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Temple Balance
              Expanded(
                flex: 3,
                child: balanceSummaryAsync.when(
                  loading: () => const Center(
                      child: SizedBox(
                          height: 40,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (err, stack) => const Center(
                      child: Icon(Icons.error_outline, color: Colors.red)),
                  data: (summary) => _BalanceDisplay(
                    label: 'ยอดเงินวัด',
                    amount: summary.templeBalance,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
              // Center: Last Export Info
              Expanded(
                flex: 3,
                child: _LastExportInfo(lastExportDate: lastExportDate),
              ),
              // Right: Action Buttons
              Expanded(
                flex: 5,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const MemberManagementScreen())),
                    icon: const Icon(Icons.groups_2_outlined, size: 32),
                    label: const Text('จัดการสมาชิก'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Second Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Members Balance
              Expanded(
                flex: 3,
                child: balanceSummaryAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (err, stack) => const SizedBox.shrink(),
                  data: (summary) => _BalanceDisplay(
                    label: 'ยอดรวมพระ',
                    amount: summary.membersBalance,
                    color: Colors.purple.shade800,
                  ),
                ),
              ),
              // Center: Empty
              Expanded(
                flex: 3,
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: onExport,
                    icon: const Icon(Icons.backup_outlined, size: 32),
                    label: const Text('ส่งออกไฟล์'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
              // Right: Add Transaction Button
              Expanded(
                flex: 4,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const AddMultiTransactionScreen())),
                    icon: const Icon(
                      Icons.add_card_outlined,
                      size: 32,
                    ),
                    label: const Text('ทำธุรกรรม'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LastExportInfo extends StatelessWidget {
  final DateTime? lastExportDate;

  const _LastExportInfo({this.lastExportDate});

  @override
  Widget build(BuildContext context) {
    if (lastExportDate == null) {
      return const Center(
        child: Text(
          'ยังไม่เคยสำรองข้อมูล',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12, color: Color.fromARGB(255, 172, 171, 171)),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('สำรองล่าสุด:', style: Theme.of(context).textTheme.labelSmall),
          Text(
            DateFormatter.formatBE(
                lastExportDate!.toLocal(), "d MMM yy (HH:mm'น.')"),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 129, 129, 129),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceDisplay extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _BalanceDisplay({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat("#,##0", "th_TH");
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(
            '฿${formatter.format(amount)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
