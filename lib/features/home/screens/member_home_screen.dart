import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:templefunds/core/services/report_generation_service.dart';
import 'package:templefunds/core/widgets/scroll_indicator_wrapper.dart';
import 'package:templefunds/core/widgets/app_dialogs.dart';
import 'package:templefunds/core/widgets/navigation_tile.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/transactions/providers/accounts_provider.dart';
import 'package:templefunds/features/transactions/screens/audit_transactions_screen.dart';
import 'package:templefunds/features/settings/screens/personal_settings_screen.dart';
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
    final accountsAsync = ref.watch(allAccountsProvider);

    final String mainName =
        ('${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim().isNotEmpty)
            ? '${user!.firstName ?? ''} ${user.lastName ?? ''}'.trim()
            : user?.nickname ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('หน้าหลัก : พระ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'ตั้งค่า',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const PersonalSettingsScreen()));
            },
          ),
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
                child: Column(
                  children: [
                    if (user?.specialTitle?.isNotEmpty ?? false)
                      Text(
                        user!.specialTitle!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    Text(
                      mainName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (user?.ordinationName?.isNotEmpty ?? false)
                      Text(
                        user!.ordinationName!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                  ],
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
              const SizedBox(height: 4),
              accountsAsync.when(
                data: (accounts) {
                  final memberAccount = accounts
                      .firstWhereOrNull((acc) => acc.ownerUserId == user?.id);
                  if (memberAccount == null) return const SizedBox.shrink();
                  return NavigationTile(
                      icon: Icons.rule_folder_outlined,
                      title: 'ตรวจสอบธุรกรรมส่วนตัว',
                      subtitle: 'ตรวจสอบรายการที่อาจบันทึกย้อนหลัง',
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => AuditTransactionsScreen(
                                account: memberAccount,
                                title: 'ตรวจสอบธุรกรรมส่วนตัว')));
                      });
                },
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}
