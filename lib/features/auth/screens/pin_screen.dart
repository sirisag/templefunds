import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPinVisible = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submit(bool isSetupMode) async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (isSetupMode) {
      if (_pinController.text != _confirmPinController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('รหัส PIN ที่ยืนยันไม่ตรงกัน'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    final pin = _pinController.text.trim();
    final notifier = ref.read(authProvider.notifier);

    if (isSetupMode) {
      await notifier.setPinAndLogin(pin);
    } else {
      await notifier.loginWithPin(pin);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isSetupMode = authState.status == AuthStatus.requiresPinSetup;
    final canPop = Navigator.of(context).canPop();

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.requiresPin && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        ref.read(authProvider.notifier).clearError();
        _pinController.clear(); // Clear input on error
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(isSetupMode ? 'ตั้งรหัส PIN' : 'ใส่รหัส PIN'),
        automaticallyImplyLeading: canPop,
        actions: [
          if (!isSetupMode)
            TextButton.icon(
              onPressed: () => ref.read(authProvider.notifier).logout(),
              icon: const Icon(Icons.logout),
              label: const Text('ออกจากระบบ'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSetupMode ? Icons.pin_invoke_outlined : Icons.pin,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  isSetupMode
                      ? 'ตั้งรหัส PIN 4 หลักสำหรับเข้าใช้งาน'
                      : 'สวัสดี, ${authState.user?.name ?? 'ผู้ใช้งาน'}\nกรุณาใส่รหัส PIN ของคุณ',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _pinController,
                  decoration: InputDecoration(
                    labelText: 'รหัส PIN (4 หลัก)',
                    border: const OutlineInputBorder(),
                    counterText: "",
                    suffixIcon: IconButton(
                      icon: Icon(_isPinVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _isPinVisible = !_isPinVisible;
                        });
                      },
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 4,
                  obscureText: !_isPinVisible,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 16),
                  validator: (value) {
                    if (value == null || value.trim().length != 4) {
                      return 'กรุณากรอกรหัส PIN 4 หลัก';
                    }
                    return null;
                  },
                ),
                if (isSetupMode) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPinController,
                    decoration: const InputDecoration(
                      labelText: 'ยืนยันรหัส PIN',
                      border: OutlineInputBorder(),
                      counterText: "",
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 4,
                    obscureText: !_isPinVisible,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 16),
                    validator: (value) {
                      if (value != _pinController.text) {
                        return 'รหัส PIN ไม่ตรงกัน';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 24),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: () => _submit(isSetupMode),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 16),
                      textStyle: Theme.of(context).textTheme.titleMedium,
                    ),
                    child:
                        Text(isSetupMode ? 'ยืนยันและเข้าสู่ระบบ' : 'เข้าสู่ระบบ'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
