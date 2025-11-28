import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:templefunds/core/widgets/app_dialogs.dart';
import 'package:templefunds/core/widgets/scroll_indicator_wrapper.dart';
import 'package:templefunds/core/services/report_generation_service.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/core/widgets/navigation_tile.dart';
import 'package:templefunds/features/transactions/providers/accounts_provider.dart';
import 'package:templefunds/features/transactions/screens/audit_transactions_screen.dart';
import 'package:templefunds/features/transactions/screens/member_transactions_screen.dart';
import 'package:templefunds/features/transactions/screens/temple_transactions_screen.dart';
import 'package:templefunds/features/settings/screens/personal_settings_screen.dart';
import '../widgets/home_image_customizer.dart';

class MasterHomeScreen extends ConsumerStatefulWidget {
  const MasterHomeScreen({super.key});

  @override
  ConsumerState<MasterHomeScreen> createState() => _MasterHomeScreenState();
}

class _MasterHomeScreenState extends ConsumerState<MasterHomeScreen> {
  File? _pickedImageFile;
  bool _isLoading = false;

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
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final accountsAsync = ref.watch(allAccountsProvider);

    final String mainName =
        ('${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim().isNotEmpty)
            ? '${user!.firstName ?? ''} ${user.lastName ?? ''}'.trim()
            : user?.nickname ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('หน้าหลัก : เจ้าอาวาส'),
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
              const SizedBox(height: 4),
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
              const Divider(),
              const SizedBox(height: 12),
              const SizedBox(height: 4),
              accountsAsync.when(
                data: (accounts) {
                  final templeAccount = accounts
                      .firstWhereOrNull((acc) => acc.ownerUserId == null);
                  if (templeAccount == null) return const SizedBox.shrink();
                  return NavigationTile(
                      icon: Icons.manage_search_outlined,
                      title: 'ตรวจสอบธุรกรรมวัด',
                      subtitle: 'ตรวจสอบรายการที่อาจบันทึกย้อนหลัง',
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => AuditTransactionsScreen(
                                account: templeAccount,
                                title: 'ตรวจสอบธุรกรรมวัด')));
                      });
                },
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const SizedBox.shrink(),
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
                      subtitle: 'ตรวจสอบรายการส่วนตัวที่อาจบันทึกย้อนหลัง',
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
