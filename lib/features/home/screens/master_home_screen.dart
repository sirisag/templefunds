import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/core/widgets/app_dialogs.dart';
import 'package:templefunds/core/widgets/navigation_tile.dart';
import 'package:templefunds/core/services/report_generation_service.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/members/screens/change_pin_screen.dart';
import 'package:templefunds/features/transactions/screens/member_transactions_screen.dart';
import 'package:templefunds/features/transactions/screens/temple_transactions_screen.dart';

class MasterHomeScreen extends ConsumerWidget {
  const MasterHomeScreen({super.key});

  Future<void> _exportReport(
    BuildContext context,
    WidgetRef ref, {
    required bool isTempleReport,
  }) async {
    final reportService = ref.read(reportGenerationServiceProvider);
    final selectedMonth = await reportService.pickMonth(context);

    if (selectedMonth != null && context.mounted) {
      if (isTempleReport) {
        await reportService.generateAndShowTempleReport(context, selectedMonth);
      } else {
        final user = ref.read(authProvider).user;
        if (user?.id != null) {
          await reportService.generateAndShowMemberReport(
              context, selectedMonth, user!.id!);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('หน้าหลัก : เจ้าอาวาส'),
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

          const SizedBox(height: 8),
          Padding(
            // This creates a 25% margin on the left and right,
            // making the image take up 50% of the screen width and centering it.
            padding: EdgeInsets.fromLTRB(
              MediaQuery.of(context).size.width * 0.15, // Left margin
              8, // Top spacing
              MediaQuery.of(context).size.width * 0.15, // Right margin
              16, // Bottom spacing
            ),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(100.0), // Creates rounded corners
              child: Image.asset('assets/icon/icon.png'),
            ),
          ),

          Center(
            child: Text(
              '${user?.name ?? 'เจ้าอาวาส'}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 20),
          // Navigation Tiles
          NavigationTile(
              icon: Icons.account_balance_outlined,
              title: 'ดูธุรกรรมของวัด',
              subtitle: 'ดูรายการรับ-จ่ายทั้งหมดของวัด',
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const TempleTransactionsScreen(),
                ));
              }),
          const SizedBox(height: 12),
          NavigationTile(
              icon: Icons.wallet_outlined,
              title: 'ดูธุรกรรมส่วนตัว',
              subtitle: 'ดูรายการรับ-จ่ายส่วนตัวของคุณ',
              onTap: () {
                if (user?.id != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          MemberTransactionsScreen(userId: user!.id!),
                    ),
                  );
                }
              }),
          const SizedBox(height: 12),
          NavigationTile(
            icon: Icons.pin_outlined,
            title: 'เปลี่ยนรหัส PIN',
            subtitle: 'เปลี่ยนรหัส PIN 4 หลักสำหรับเข้าใช้งาน',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePinScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
