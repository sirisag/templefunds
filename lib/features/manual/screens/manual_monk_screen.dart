import 'package:flutter/material.dart';

class ManualMonkScreen extends StatelessWidget {
  const ManualMonkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('คู่มือพระลูกวัด'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSection(
            context,
            icon: Icons.wallet_outlined,
            title: 'ดูบัญชีส่วนตัว',
            content:
                '• สามารถดูรายการรับ-จ่ายทั้งหมดในบัญชีส่วนตัวของท่านได้เท่านั้น',
          ),
          _buildSection(
            context,
            icon: Icons.pin_outlined,
            title: 'การตั้งค่าส่วนตัว',
            content:
                '• สามารถเปลี่ยนรหัส PIN, ตั้งค่าการเข้าระบบด้วยลายนิ้วมือ, และเปลี่ยนธีมสีของแอปได้',
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
