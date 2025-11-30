import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:templefunds/features/auth/widgets/pin_form_field.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';
import 'package:templefunds/core/services/secure_storage_service.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState
    extends ConsumerState<SecuritySettingsScreen> {
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final LocalAuthentication auth = LocalAuthentication();
    final canCheck = await auth.canCheckBiometrics;
    if (mounted) {
      setState(() {
        _canCheckBiometrics = canCheck;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // If turning on, require PIN confirmation
      final pin = await _showPinConfirmationDialog();
      if (pin == null) return; // User cancelled

      final isPinCorrect = await SecureStorageService().verifyPin(pin);
      if (!isPinCorrect) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('รหัส PIN ไม่ถูกต้อง'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }
    // If turning off, or if PIN was correct, update the setting
    await ref
        .read(biometricSettingsProvider.notifier)
        .setBiometricEnabled(value);
  }

  Future<String?> _showPinConfirmationDialog() {
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันรหัส PIN ของคุณ'),
        content: Form(
          key: formKey,
          child: PinFormField(
            controller: pinController,
            labelText: 'รหัส PIN',
            isPinVisible: false,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(pinController.text);
              }
            },
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBiometricEnabled =
        ref.watch(biometricSettingsProvider).asData?.value ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('ความปลอดภัย')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_canCheckBiometrics)
            SwitchListTile(
              title: const Text('เข้าสู่ระบบด้วยลายนิ้วมือ'),
              subtitle: const Text(
                  'ใช้ลายนิ้วมือที่ลงทะเบียนไว้กับเครื่องเพื่อเข้าสู่ระบบแทนการกรอก PIN'),
              value: isBiometricEnabled,
              onChanged: _toggleBiometric,
            ),
        ],
      ),
    );
  }
}
