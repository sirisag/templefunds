import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';
import 'package:templefunds/features/recovery/screens/use_recovery_code_screen.dart';
import '../providers/auth_provider.dart';
import '../widgets/login_error_dialog.dart';
import 'pin_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _id1Controller = TextEditingController();
  final _id2Controller = TextEditingController();
  bool _isLoading = false;
  Timer? _timer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Check initial lockout state when the screen is first built.
    final initialLockout = ref.read(authProvider).lockoutUntil;
    if (initialLockout != null) {
      _updateRemainingTime(initialLockout);
    }
  }

  void _updateRemainingTime(DateTime lockoutUntil) {
    if (!mounted) return;
    setState(() {
      _remainingTime = lockoutUntil.difference(DateTime.now());
      if (_remainingTime.isNegative) _remainingTime = Duration.zero;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel(); // Cancel any existing timer.
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        setState(() => _remainingTime -= const Duration(seconds: 1));
      } else {
        _timer?.cancel();
        setState(() {}); // Force rebuild to re-enable the button.
      }
    });
  }

  @override
  void dispose() {
    _id1Controller.dispose();
    _id2Controller.dispose();
    _timer?.cancel();
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

    final result = await ref.read(authProvider.notifier).loginWithIds(
          id1: _id1Controller.text.trim(),
          id2: _id2Controller.text.trim(),
        );

    if (mounted) {
      if (result == null) {
        // Success
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PinScreen()),
        );
      } else {
        final (errorMessage, lockoutUntil) = result;
        // Failure: Show dialog first
        await showDialog(
          context: context,
          builder: (_) => LoginErrorDialog(
            errorMessage: errorMessage,
          ),
        );
        // After dialog, if there's a lockout, update the timer.
        if (lockoutUntil != null) _updateRemainingTime(lockoutUntil);
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeStyleAsync = ref.watch(homeStyleProvider);
    // Listen to changes in the lockout state from the provider.
    ref.listen(authProvider.select((s) => s.lockoutUntil), (_, next) {
      if (next != null) {
        _updateRemainingTime(next);
      }
    });

    final isLocked = _remainingTime.inSeconds > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('เข้าสู่ระบบ'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                homeStyleAsync.when(
                  data: (style) {
                    ImageProvider imageProvider;
                    if (style.imagePath != null &&
                        File(style.imagePath!).existsSync()) {
                      imageProvider = FileImage(File(style.imagePath!));
                    } else {
                      imageProvider = const AssetImage('assets/icon/icon.png');
                    }

                    final horizontalPadding = (1 - style.widthMultiplier) / 2;

                    return Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width *
                              horizontalPadding),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(style.cornerRadius),
                        child: Container(
                          width: MediaQuery.of(context).size.width *
                              style.widthMultiplier,
                          height: MediaQuery.of(context).size.width *
                              style.heightMultiplier,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                                fit: BoxFit.cover, image: imageProvider),
                          ),
                        ),
                      ),
                    );
                  },
                  loading: () => const CircleAvatar(
                      radius: 80, child: CircularProgressIndicator()),
                  error: (e, st) =>
                      const CircleAvatar(radius: 80, child: Icon(Icons.error)),
                ),
                const SizedBox(height: 24),
                Text(
                  'กรุณากรอกรหัสเพื่อเข้าสู่ระบบ',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
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
                  validator: (value) {
                    if (value == null || value.trim().length != 4) {
                      return 'กรุณากรอกรหัส 4 หลัก';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _id2Controller,
                  decoration: const InputDecoration(
                    labelText: 'รหัสยืนยันตัวตน (ID ชุดที่ 2)',
                    prefixIcon: Icon(Icons.password_outlined),
                    counterText: "",
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 4,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.trim().length != 4) {
                      return 'กรุณากรอกรหัส 4 หลัก';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (isLocked)
                  ElevatedButton.icon(
                    onPressed: null, // Disabled
                    icon: const Icon(Icons.timer_outlined),
                    label: Text(
                        'กรุณารอ ${_remainingTime.inMinutes}:${(_remainingTime.inSeconds % 60).toString().padLeft(2, '0')}'),
                    style: ElevatedButton.styleFrom(
                        disabledBackgroundColor: Colors.grey.shade300),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.login),
                    label: const Text('เข้าสู่ระบบ'),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const UseRecoveryCodeScreen()),
                    );
                  },
                  child: const Text('ลืมรหัสผ่าน? ใช้รหัสกู้คืน'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
