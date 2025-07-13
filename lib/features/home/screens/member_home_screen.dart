import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/core/services/report_generation_service.dart';
import 'package:templefunds/core/widgets/app_dialogs.dart';
import 'package:templefunds/core/widgets/navigation_tile.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/members/screens/change_pin_screen.dart';
import 'package:templefunds/features/transactions/screens/member_transactions_screen.dart';

class MemberHomeScreen extends ConsumerWidget {
  const MemberHomeScreen({super.key});

  Future<void> _exportReport(BuildContext context, WidgetRef ref) async {
    final reportService = ref.read(reportGenerationServiceProvider);
    final selectedMonth = await reportService.pickMonth(context);

    if (selectedMonth != null && context.mounted) {
      final user = ref.read(authProvider).user;
      if (user?.id != null) {
        await reportService.generateAndShowMemberReport(
            context, selectedMonth, user!.id!);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: Text('หน้าหลัก (${user?.role ?? "สมาชิก"})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: () => showLogoutConfirmationDialog(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'ยินดีต้อนรับ, ${user?.name ?? 'สมาชิก'}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          NavigationTile(
            icon: Icons.wallet_outlined,
            title: 'ดูบัญชีส่วนตัว',
            subtitle: 'ดูรายการรับ-จ่ายทั้งหมดของคุณ',
            onTap: () {
              if (user?.id != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MemberTransactionsScreen(userId: user!.id!),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          NavigationTile(
            icon: Icons.picture_as_pdf_outlined,
            title: 'ส่งออกรายงานส่วนตัว',
            subtitle: 'สร้างรายงาน PDF ของบัญชีส่วนตัว (เลือกเดือน)',
            onTap: () => _exportReport(context, ref),
          ),
          const SizedBox(height: 12),
          NavigationTile(
            icon: Icons.pin_outlined,
            title: 'เปลี่ยนรหัส PIN',
            subtitle: 'เปลี่ยนรหัส PIN 4 หลักสำหรับเข้าใช้งาน',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ChangePinScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
