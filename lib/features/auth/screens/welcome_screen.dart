import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../providers/auth_provider.dart';
import '../../members/providers/members_provider.dart';
import '../../transactions/providers/accounts_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../transactions/providers/transactions_provider.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _idController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _dbExists = false;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    // Call the provider method to process the ID
    await ref.read(authProvider.notifier).processId1(_idController.text.trim());

    // The AuthWrapper in main.dart will handle navigation based on the new state.
    // We just need to handle the loading state on this screen.
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _importFile() async {
    // Show a confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการนำเข้าไฟล์'),
        content: const Text(
            'การนำเข้าไฟล์จะเขียนทับข้อมูลที่มีอยู่ทั้งหมด (ถ้ามี) คุณแน่ใจหรือไม่?'),
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
    }
  }

  Future<void> _resetApp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการเริ่มใหม่'),
        content: const Text(
            'การกระทำนี้จะลบข้อมูลทั้งหมดในแอปและกลับสู่สถานะเริ่มต้น คุณแน่ใจหรือไม่?'),
        actions: [
          TextButton(
            child: const Text('ยกเลิก'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
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

  @override
  Widget build(BuildContext context) {
    // Listen for errors from the provider and show a SnackBar
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.loggedOut && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        // Clear the error so it doesn't show again on rebuild
        ref.read(authProvider.notifier).clearError();
      }
    });
    final templeNameAsync = ref.watch(templeNameProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 80,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text('แอปพลิเคชั่น',
                              style: Theme.of(context).textTheme.headlineMedium),
                          Text('บันทึกรายการบัญชีวัด',
                              style: Theme.of(context).textTheme.headlineMedium),
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
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .secondary),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                            loading: () => const SizedBox.shrink(),
                            error: (e, s) => const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 40),
                          TextFormField(
                            controller: _idController,
                            decoration: const InputDecoration(
                              labelText: 'รหัสประจำตัว (4 หลัก)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_outline),
                              counterText: "", // Hide the counter
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            maxLength: 4,
                            validator: (value) {
                              if (value == null || value.trim().length != 4) {
                                return 'กรุณากรอกรหัส 4 หลัก';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : ElevatedButton.icon(
                                  onPressed: _submit,
                                  icon: const Icon(Icons.login),
                                  label: const Text('ตกลง'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 40, vertical: 16),
                                    textStyle:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_dbExists)
                    TextButton.icon(
                      onPressed: _resetApp,
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: const Text('เริ่มใหม่'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
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
    );
  }
}