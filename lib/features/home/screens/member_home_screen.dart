import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/core/services/report_generation_service.dart';
import 'package:templefunds/core/widgets/scroll_indicator_wrapper.dart';
import 'package:templefunds/core/widgets/app_dialogs.dart';
import 'package:templefunds/core/widgets/navigation_tile.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/members/screens/change_pin_screen.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';
import 'package:templefunds/features/settings/widgets/theme_color_picker.dart';
import 'package:templefunds/features/transactions/screens/member_transactions_screen.dart';
import '../widgets/home_image_customizer.dart';

class MemberHomeScreen extends ConsumerStatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  ConsumerState<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends ConsumerState<MemberHomeScreen> {
  File? _pickedImageFile;
  bool _isLoading = false;

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
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('หน้าหลัก : พระ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: () => showLogoutConfirmationDialog(context, ref),
          ),
        ],
      ),
      body: ScrollIndicatorWrapper(
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
            children: [
              const SizedBox(height: 8),
              CustomizableHomeImage(pickedImageFile: _pickedImageFile),
              Center(
                child: Text(
                  user?.name ?? 'สมาชิก',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
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
                        builder: (_) =>
                            MemberTransactionsScreen(userId: user!.id!),
                      ),
                    );
                  }
                },
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
              const SizedBox(height: 24),
              const Text('เลือกธีมสีของแอป',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const ThemeColorPicker(),
              const SizedBox(height: 24),
              ImageCustomizationControls(
                isLoading: _isLoading,
                onImagePicked: (file) {
                  setState(() {
                    _pickedImageFile = file;
                  });
                },
                imageFile: _pickedImageFile,
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}
