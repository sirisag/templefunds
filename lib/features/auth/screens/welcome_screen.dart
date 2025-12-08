import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart'; // Import kDebugMode
import 'package:templefunds/features/manual/screens/manual_main_screen.dart';
import 'package:flutter/services.dart';
import 'package:templefunds/features/recovery/providers/recovery_codes_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../providers/auth_provider.dart';
import '../widgets/login_error_dialog.dart';
import '../../members/providers/members_provider.dart';
import 'login_screen.dart';
import 'temple_registration_screen.dart';
import '../../../core/debug/database_seeder.dart';
import '../../transactions/providers/accounts_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../transactions/providers/transactions_provider.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _isLoading = false;
  bool _dbExists = false;

  @override
  void initState() {
    super.initState();
    // Clear the image cache on init to ensure the latest logo is displayed,
    // preventing issues where an old cached logo is shown after an update.
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _checkDbStatus();
  }

  Future<void> _checkDbStatus() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'temple_funds.db');
    final exists = await databaseExists(path);
    if (mounted) {
      setState(() => _dbExists = exists);
    }
  }

  Future<void> _importFile() async {
    // Show a confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการนำเข้าไฟล์'),
        content: const Text(
          'การนำเข้าไฟล์จะเขียนทับข้อมูลที่มีอยู่ทั้งหมด (ถ้ามี) คุณแน่ใจหรือไม่?',
        ),
        actions: [
          TextButton(
            child: const Text('ยกเลิก'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('ยืนยัน'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await ref.read(authProvider.notifier).importDatabaseFile();

    if (mounted) {
      if (success) {
        // After a successful import, the DB status has changed.
        await _checkDbStatus(); // Refresh the UI state
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('นำเข้าไฟล์สำเร็จ! กรุณาเข้าสู่ระบบด้วยรหัสของคุณ'),
            backgroundColor: Colors.green,
          ),
        );
      }
      // Error snackbar is handled by the authProvider listener
    }
  }

  Future<void> _resetApp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการเริ่มใหม่'),
        content: const Text(
          'การกระทำนี้จะลบข้อมูลทั้งหมดในแอปและกลับสู่สถานะเริ่มต้น คุณแน่ใจหรือไม่?',
        ),
        actions: [
          TextButton(
            child: const Text('ยกเลิก'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('ยืนยันลบข้อมูล'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).resetApp();
      // Invalidate all major data providers to force a full refresh
      ref.invalidate(membersProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(allAccountsProvider);
      ref.invalidate(recoveryCodesProvider);

      // After resetting, we should also check the DB status again to update the UI
      await _checkDbStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('รีเซ็ตแอปเรียบร้อยแล้ว'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _seedData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('โหมดทดลองใช้งาน'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'การกระทำนี้จะลบข้อมูลปัจจุบันทั้งหมดและสร้างข้อมูลจำลองเพื่อให้คุณได้ทดลองใช้งานฟังก์ชันต่างๆ ของแอป'),
            SizedBox(height: 16),
            Text(
                'หลังจากสร้างข้อมูลเสร็จแล้ว ให้ใช้ข้อมูลด้านล่างเพื่อเข้าสู่ระบบ:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(' • รหัสประจำตัว (ID1): 9999'),
            Text(' • รหัสยืนยัน (ID2): 1111'),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('ยกเลิก'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('ยืนยันและเริ่ม'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await ref.read(databaseSeederProvider).seedDatabase();
        await _checkDbStatus(); // Refresh UI
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('สร้างข้อมูลจำลองสำเร็จ!'),
            backgroundColor: Colors.green,
          ));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final templeNameAsync = ref.watch(templeNameProvider);
    final homeStyleAsync = ref.watch(homeStyleProvider);

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 8),
                            homeStyleAsync.when(
                              data: (style) {
                                ImageProvider imageProvider;
                                if (style.imagePath != null &&
                                    File(style.imagePath!).existsSync()) {
                                  imageProvider =
                                      FileImage(File(style.imagePath!));
                                } else {
                                  imageProvider =
                                      const AssetImage('assets/icon/icon.png');
                                }

                                final horizontalPadding =
                                    (1 - style.widthMultiplier) / 2;

                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal:
                                          MediaQuery.of(context).size.width *
                                              horizontalPadding),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                        style.cornerRadius),
                                    child: Container(
                                      width: MediaQuery.of(context).size.width *
                                          style.widthMultiplier,
                                      height:
                                          MediaQuery.of(context).size.width *
                                              style.heightMultiplier,
                                      decoration: BoxDecoration(
                                        image: DecorationImage(
                                            fit: BoxFit.cover,
                                            image: imageProvider),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              loading: () => const CircularProgressIndicator(),
                              error: (e, s) =>
                                  const Icon(Icons.error, size: 80),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'แอปพลิเคชั่น',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            Text(
                              'บันทึกรายการบัญชีวัด',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            templeNameAsync.when(
                              data: (name) => (name != null && name.isNotEmpty)
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.secondary,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                              loading: () => const SizedBox.shrink(),
                              error: (e, s) => const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 24),
                            _isLoading
                                ? const CircularProgressIndicator()
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context)
                                              .push(MaterialPageRoute(
                                            builder: (_) => const LoginScreen(),
                                          ));
                                        },
                                        icon: const Icon(Icons.login),
                                        label: const Text('เข้าสู่ระบบ'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          textStyle: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context)
                                              .push(MaterialPageRoute(
                                            builder: (_) =>
                                                const TempleRegistrationScreen(),
                                          ));
                                        },
                                        icon:
                                            const Icon(Icons.app_registration),
                                        label: const Text(
                                            'ลงทะเบียนวัด (สำหรับผู้ดูแล)'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                TextButton.icon(
                                  onPressed: _resetApp,
                                  icon:
                                      const Icon(Icons.delete_forever_outlined),
                                  label: const Text('เริ่มใหม่'),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _importFile,
                                  icon: const Icon(Icons.file_upload_outlined),
                                  label: const Text('นำเข้าข้อมูล'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ManualMainScreen()));
                    },
                    icon: const Icon(Icons.help_outline),
                    label: const Text('คู่มือ'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black.withOpacity(0.4),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _seedData,
                    icon: const Icon(Icons.data_exploration_outlined),
                    label: const Text('ทดลองใช้งาน'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black54,
                      backgroundColor: Colors.purple.withOpacity(0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
