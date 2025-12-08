import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:templefunds/core/models/user_model.dart';
import 'package:templefunds/features/home/screens/admin_home_screen.dart';
import 'package:templefunds/features/home/screens/master_home_screen.dart';
import 'package:templefunds/features/home/screens/member_home_screen.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/pin_form_field.dart';
import '../widgets/login_error_dialog.dart';

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _pinFocusNode = FocusNode();
  final _confirmPinFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPinVisible = false;
  Timer? _timer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    final initialLockout = ref.read(authProvider).lockoutUntil;
    if (initialLockout != null) {
      _updateRemainingTime(initialLockout);
    }
    // Attempt biometric auth automatically when the screen loads
    _authenticateWithBiometrics(isAutoTrigger: true);
  }

  Future<void> _authenticateWithBiometrics({bool isAutoTrigger = false}) async {
    final isBiometricEnabled =
        ref.read(biometricSettingsProvider).asData?.value ?? false;
    if (!isBiometricEnabled) return;

    final LocalAuthentication auth = LocalAuthentication();
    final bool canCheckBiometrics = await auth.canCheckBiometrics;
    if (!canCheckBiometrics || !mounted) return;

    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'กรุณายืนยันตัวตนเพื่อเข้าสู่ระบบ',
        options: const AuthenticationOptions(
          stickyAuth: true, // Keep the dialog open on failure
          biometricOnly: true, // Only allow biometrics, no device PIN fallback
        ),
      );

      if (didAuthenticate) {
        _navigateToHomeScreen();
      }
    } on PlatformException catch (e) {
      // Handle errors, e.g., user has not set up biometrics.
      debugPrint('Biometric authentication error: $e');
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
    _pinController.dispose();
    _confirmPinController.dispose();
    _pinFocusNode.dispose();
    _confirmPinFocusNode.dispose();
    _timer?.cancel();
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
      // After setup, the state becomes loggedIn, so we can navigate.
      if (mounted && ref.read(authProvider).status == AuthStatus.loggedIn) {
        _navigateToHomeScreen();
      }
    } else {
      final result = await notifier.loginWithPin(pin);
      if (mounted) {
        if (result == null) {
          // Success
          _navigateToHomeScreen();
        } else {
          final (errorMessage, lockoutUntil) = result;
          // Failure: Show dialog first
          await showDialog(
              context: context,
              builder: (_) => LoginErrorDialog(errorMessage: errorMessage));
          // After dialog, if there's a lockout, update the timer.
          if (lockoutUntil != null) _updateRemainingTime(lockoutUntil);
        }
      }
    }

    // This should only be called if login fails, to re-enable the button.
    if (mounted && ref.read(authProvider).status != AuthStatus.loggedIn) {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToHomeScreen() {
    final user = ref.read(authProvider).user;
    Widget homeScreen;
    if (user?.role == UserRole.Admin) {
      homeScreen = const AdminHomeScreen();
    } else if (user?.role == UserRole.Master) {
      homeScreen = const MasterHomeScreen();
    } else {
      homeScreen = const MemberHomeScreen();
    }
    // Replace the entire navigation stack up to this point with the new home screen.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => homeScreen),
      (route) => false, // This predicate removes all previous routes
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isSetupMode = authState.status == AuthStatus.requiresPinSetup;
    final canPop = Navigator.of(context).canPop();
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
        title: Text(isSetupMode ? 'ตั้งรหัส PIN' : 'ใส่รหัส PIN'),
        automaticallyImplyLeading: canPop,
        actions: [
          if (!isSetupMode)
            TextButton.icon(
              onPressed: () async {
                // เปลี่ยนจากการ logout ทันที เป็นการกลับไปหน้า Welcome
                await ref.read(authProvider.notifier).goBackToWelcomeScreen();
              },
              icon: const Icon(Icons.logout),
              label: const Text('ออกจากระบบ'),
              style: TextButton.styleFrom(
                foregroundColor: Color.fromARGB(255, 61, 60, 60),
              ),
            ),
        ],
      ),
      body: Center(
        // Wrap with SafeArea to avoid system UI
        child: SafeArea(
          // Wrap with SingleChildScrollView for scrollability
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
                        imageProvider =
                            const AssetImage('assets/icon/icon.png');
                      }

                      final horizontalPadding = (1 - style.widthMultiplier) / 2;

                      return Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width *
                                horizontalPadding),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(style.cornerRadius),
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
                    loading: () => const SizedBox(
                        height: 160,
                        child: Center(child: CircularProgressIndicator())),
                    error: (e, st) => const SizedBox(
                        height: 160,
                        child: Center(child: Icon(Icons.error, size: 80))),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isSetupMode
                        ? 'ตั้งรหัส PIN 4 หลักสำหรับเข้าใช้งาน' // This dialog is for changing nickname, should be replaced with a proper edit screen later
                        : 'สวัสดี, ${authState.user?.nickname ?? 'ผู้ใช้งาน'}\nกรุณาใส่รหัส PIN ของคุณ',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 32),
                  PinFormField(
                    controller: _pinController,
                    focusNode: _pinFocusNode,
                    labelText: 'รหัส PIN (4 หลัก)',
                    isPinVisible: _isPinVisible,
                    onFieldSubmitted: (_) {
                      if (isSetupMode) {
                        _confirmPinFocusNode.requestFocus();
                      } else {
                        _submit(isSetupMode);
                      }
                    },
                  ),
                  if (isSetupMode) ...[
                    const SizedBox(height: 16),
                    PinFormField(
                      controller: _confirmPinController,
                      focusNode: _confirmPinFocusNode,
                      labelText: 'ยืนยันรหัส PIN',
                      isPinVisible: _isPinVisible,
                      onFieldSubmitted: (_) => _submit(isSetupMode),
                      validator: (value) {
                        if (value != _pinController.text) {
                          return 'รหัส PIN ไม่ตรงกัน';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isPinVisible = !_isPinVisible;
                        });
                      },
                      icon: Icon(_isPinVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      label: Text(_isPinVisible ? 'ซ่อนรหัส' : 'แสดงรหัส'),
                    ),
                  ),
                  if (_isLoading) const CircularProgressIndicator(),
                  if (!_isLoading && isLocked)
                    ElevatedButton.icon(
                      onPressed: null, // Disabled
                      icon: const Icon(Icons.timer_outlined),
                      label: Text(
                          'กรุณารอ ${_remainingTime.inMinutes}:${(_remainingTime.inSeconds % 60).toString().padLeft(2, '0')}'),
                      style: ElevatedButton.styleFrom(
                          disabledBackgroundColor: Colors.grey.shade300),
                    ),
                  if (!_isLoading && !isLocked) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!isSetupMode)
                          IconButton(
                            icon: const Icon(Icons.fingerprint),
                            iconSize: 40,
                            tooltip: 'ใช้ลายนิ้วมือ',
                            onPressed: () => _authenticateWithBiometrics(
                                isAutoTrigger: false),
                          ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _submit(isSetupMode),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 16,
                            ),
                            textStyle: Theme.of(context).textTheme.titleMedium,
                          ),
                          child: Text(
                            isSetupMode
                                ? 'ยืนยันและเข้าสู่ระบบ'
                                : 'เข้าสู่ระบบ',
                          ),
                        ),
                      ],
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
