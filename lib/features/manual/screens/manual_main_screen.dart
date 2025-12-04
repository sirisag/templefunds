import 'package:flutter/material.dart';
import 'package:templefunds/core/widgets/navigation_tile.dart';
import 'package:templefunds/features/manual/screens/manual_admin_screen.dart';
import 'package:templefunds/features/manual/screens/manual_master_screen.dart';
import 'package:templefunds/features/manual/screens/manual_monk_screen.dart';

class ManualMainScreen extends StatelessWidget {
  const ManualMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('คู่มือการใช้งาน'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ภาพรวมแอปพลิเคชัน',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'แอปพลิเคชันนี้ถูกออกแบบมาเพื่อช่วยในการบริหารจัดการการเงินภายในวัดให้มีความโปร่งใสและตรวจสอบได้ง่าย โดยแบ่งผู้ใช้งานออกเป็น 3 ระดับตามบทบาทหน้าที่ และมีฟังก์ชันหลักคือการจัดการสมาชิก, การบันทึกธุรกรรม, และการออกรายงานสรุปผล',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'เลือกดูคู่มือตามบทบาทของคุณ',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          NavigationTile(
            icon: Icons.admin_panel_settings_outlined,
            title: 'สำหรับไวยาวัจกรณ์ (Admin)',
            subtitle: 'จัดการทุกอย่างในระบบ',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ManualAdminScreen())),
          ),
          NavigationTile(
            icon: Icons.school_outlined,
            title: 'สำหรับเจ้าอาวาส (Master)',
            subtitle: 'ดูภาพรวมและตรวจสอบข้อมูล',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ManualMasterScreen())),
          ),
          NavigationTile(
            icon: Icons.person_outline,
            title: 'สำหรับพระลูกวัด (Monk)',
            subtitle: 'ดูข้อมูลและธุรกรรมส่วนตัว',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ManualMonkScreen())),
          ),
        ],
      ),
    );
  }
}
