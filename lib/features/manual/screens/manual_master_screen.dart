import 'package:flutter/material.dart';

class ManualMasterScreen extends StatelessWidget {
  const ManualMasterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('คู่มือเจ้าอาวาส'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSection(
            context,
            icon: Icons.account_balance_outlined,
            title: 'การดูธุรกรรม',
            content:
                '• สามารถดูรายการรับ-จ่ายทั้งหมดของ "บัญชีวัด" และ "บัญชีส่วนตัว" ของท่านได้',
          ),
          _buildSection(
            context,
            icon: Icons.manage_search_outlined,
            title: 'การตรวจสอบ',
            content:
                '• มีเมนูสำหรับตรวจสอบรายการที่ถูกบันทึกย้อนหลังโดยเฉพาะ เพื่อความโปร่งใส',
          ),
          _buildSection(
            context,
            icon: Icons.picture_as_pdf_outlined,
            title: 'การออกรายงาน',
            content:
                '• สามารถเลือกเดือนและส่งออกรายงานสรุปยอดบัญชีวัดและบัญชีส่วนตัวเป็นไฟล์ PDF ได้',
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
