import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../widgets/login_error_dialog.dart';

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
      if (next.errorMessage != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => LoginErrorDialog(
            errorMessage: next.errorMessage!,
            lockoutUntil: next.lockoutUntil,
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
                foregroundColor: Color.fromARGB(255, 61, 60, 60),
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
       //   const SizedBox(height: 8),
          Padding(
            // This creates a 25% margin on the left and right,
            // making the image take up 50% of the screen width and centering it.
            padding: EdgeInsets.fromLTRB(
              MediaQuery.of(context).size.width * 0.15, // Left margin
              8, // Top spacing
              MediaQuery.of(context).size.width * 0.15, // Right margin
              16, // Bottom spacing
            ),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(100.0), // Creates rounded corners
              child: Image.asset('assets/icon/icon.png'),
            ),
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
