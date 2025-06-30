import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';

class MasterHomeScreen extends ConsumerWidget {
  const MasterHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('หน้าหลัก (เจ้าอาวาส)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: () {
              // Show a confirmation dialog before logging out
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('ยืนยันการออกจากระบบ'),
                  content: const Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
                  actions: [
                    TextButton(
                      child: const Text('ยกเลิก'),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                    TextButton(
                      child: const Text('ตกลง'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ref.read(authProvider.notifier).logout();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'ยินดีต้อนรับ, ${user?.name ?? 'เจ้าอาวาส'}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          // Navigation Tiles
          _buildNavigationTile(context,
              icon: Icons.account_balance_outlined,
              title: 'ดูธุรกรรมของวัด',
              subtitle: 'ดูรายการรับ-จ่ายทั้งหมดของวัด',
              onTap: () { /* TODO: Navigate to temple transaction list */ }),
          const SizedBox(height: 12),
          _buildNavigationTile(context,
              icon: Icons.wallet_outlined,
              title: 'ดูธุรกรรมส่วนตัว',
              subtitle: 'ดูรายการรับ-จ่ายส่วนตัวของคุณ',
              onTap: () { /* TODO: Navigate to personal transaction list */ }),
        ],
      ),
    );
  }

  Widget _buildNavigationTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}