import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';

class MemberHomeScreen extends ConsumerWidget {
  const MemberHomeScreen({super.key});

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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ยินดีต้อนรับ, ${user?.name ?? 'สมาชิก'}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            const Text('คุณกำลังเข้าสู่ระบบในฐานะสมาชิก'),
            // TODO: Add member-specific widgets here, like viewing their own transactions.
          ],
        ),
      ),
    );
  }
}