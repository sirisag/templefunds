import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/auth/screens/pin_screen.dart';
import 'package:templefunds/features/auth/widgets/login_error_dialog.dart';

class UseRecoveryCodeScreen extends ConsumerStatefulWidget {
  const UseRecoveryCodeScreen({super.key});

  @override
  ConsumerState<UseRecoveryCodeScreen> createState() =>
      _UseRecoveryCodeScreenState();
}

class _UseRecoveryCodeScreenState extends ConsumerState<UseRecoveryCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _id1Controller = TextEditingController();
  final _recoveryCodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _id1Controller.dispose();
    _recoveryCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    final result = await ref.read(authProvider.notifier).recoverAccount(
          userId1: _id1Controller.text.trim(),
          recoveryCode: _recoveryCodeController.text.trim(),
        );

    if (mounted) {
      if (result == null) {
        // Success
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PinScreen()),
        );
      } else {
        final (errorMessage, lockoutUntil) = result;
        // Failure: Show dialog first, then update UI
        await showDialog(
            context: context,
            builder: (_) => LoginErrorDialog(
                  errorMessage: errorMessage,
                  lockoutUntil: lockoutUntil,
                ));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('กู้คืนบัญชี'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.shield_moon_outlined,
                    size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'กรอกรหัสเพื่อกู้คืนบัญชี',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _id1Controller,
                  decoration: const InputDecoration(
                    labelText: 'รหัสประจำตัว (ID ชุดที่ 1)',
                    prefixIcon: Icon(Icons.person_outline),
                    counterText: "",
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 4,
                  validator: (v) => (v == null || v.trim().length != 4)
                      ? 'ต้องมี 4 หลัก'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _recoveryCodeController,
                  decoration: const InputDecoration(
                    labelText: 'รหัสกู้คืนฉุกเฉิน (10 หลัก)',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                    counterText: "",
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 10,
                  obscureText: true,
                  validator: (v) => (v == null || v.trim().length != 10)
                      ? 'ต้องมี 10 หลัก'
                      : null,
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.blue.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.blue.shade300, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'รหัสกู้คืนแต่ละรหัสสามารถใช้ได้เพียงครั้งเดียวเท่านั้น หลังจากใช้งานแล้วควรทำลายรหัสที่ใช้แล้วทิ้ง',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.login),
                        label: const Text('ยืนยันและตั้ง PIN ใหม่'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
