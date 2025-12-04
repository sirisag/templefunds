import 'package:flutter/material.dart';

class ManualAdminScreen extends StatelessWidget {
  const ManualAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('คู่มือไวยาวัจกรณ์'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSection(
            context,
            icon: Icons.groups_outlined,
            title: 'การจัดการสมาชิก',
            content:
                '• สามารถ เพิ่ม, แก้ไข, ระงับการใช้งาน และเปลี่ยนบทบาทของสมาชิกได้จากเมนู "จัดการสมาชิก"\n• สามารถรีเซ็ตรหัสยืนยัน (ID ชุดที่ 2) ให้กับสมาชิกได้',
          ),
          _buildSection(
            context,
            icon: Icons.add_card_outlined,
            title: 'การทำธุรกรรม',
            content:
                '• สามารถทำธุรกรรมได้ 3 รูปแบบ: บัญชีวัด, บัญชีส่วนตัว, และหลายบัญชีพร้อมกัน\n• สามารถแนบรูปภาพใบเสร็จ และบันทึกรายการย้อนหลังได้',
          ),
          _buildSection(
            context,
            icon: Icons.settings_outlined,
            title: 'การตั้งค่าระบบ',
            content:
                '• สามารถเปลี่ยนชื่อวัด, ชื่อไฟล์ส่งออก, โลโก้, ธีมสี และขนาดตัวอักษรได้\n• สามารถตั้งค่าการแจ้งเตือนการสำรองข้อมูลได้',
          ),
          _buildSection(
            context,
            icon: Icons.backup_outlined,
            title: 'การสำรองและกู้คืนข้อมูล',
            content:
                '• ส่งออก (Export): สร้างไฟล์สำรองข้อมูลที่เข้ารหัสทั้งหมดของวัด\n• นำเข้า (Import): กู้คืนข้อมูลทั้งหมดจากไฟล์ที่เคยสำรองไว้',
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context,
      {required IconData icon,
      required String title,
      required String content}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
            const Divider(height: 20),
            Text(content),
          ],
        ),
      ),
    );
  }
}
