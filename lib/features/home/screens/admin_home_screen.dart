import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/members/screens/member_management_screen.dart';

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  bool _isExporting = false;

  Future<void> _exportData() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      await ref.read(authProvider.notifier).exportDatabaseFile();
      // The share sheet appearing is a success indicator, no need for a SnackBar.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst("Exception: ", "")),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('หน้าหลักผู้ดูแล'),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'ส่งออกข้อมูล',
              onPressed: _exportData,
            ),
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
            'ยินดีต้อนรับ, ${user?.name ?? 'ผู้ดูแล'}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),

          // Summary Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ภาพรวม',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  const ListTile(
                    leading: Icon(Icons.account_balance_wallet_outlined),
                    title: Text('ยอดเงินคงเหลือรวม'),
                    trailing: Text(
                      '฿ 0.00', // Placeholder
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const ListTile(
                    leading: Icon(Icons.people_alt_outlined),
                    title: Text('จำนวนสมาชิกในระบบ'),
                    trailing: Text(
                      '0 คน', // Placeholder
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Navigation Tiles
          _buildNavigationTile(context, icon: Icons.receipt_long_outlined, title: 'จัดการธุรกรรม', subtitle: 'ดูและเพิ่มรายการรับ-จ่ายทั้งหมด', onTap: () { /* TODO: Navigate */ }),
          const SizedBox(height: 12),
          _buildNavigationTile(context,
              icon: Icons.manage_accounts_outlined,
              title: 'จัดการสมาชิก',
              subtitle: 'เพิ่ม, แก้ไข, หรือลบสมาชิกในระบบ', onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MemberManagementScreen()));
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to AddEditTransactionScreen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไปที่หน้าเพิ่มธุรกรรม')),
          );
        },
        label: const Text('เพิ่มธุรกรรม'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNavigationTile(BuildContext context, { required IconData icon, required String title, required String subtitle, required VoidCallback onTap, }) {
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
