import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _pinFocusNode.dispose();
    _confirmPinFocusNode.dispose();
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

      // After setting the PIN, the state becomes `loggedIn`.
      // Instead of relying on the AuthWrapper, we explicitly navigate to the correct home screen
      // to avoid race conditions and navigation stack issues.
      final newAuthState = ref.read(authProvider);
      if (newAuthState.status == AuthStatus.loggedIn) {
        final user = newAuthState.user;
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isSetupMode = authState.status == AuthStatus.requiresPinSetup;
    final canPop = Navigator.of(context).canPop();
    final homeStyleAsync = ref.watch(homeStyleProvider);

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
                    loading: () => const CircleAvatar(
                        radius: 80, child: CircularProgressIndicator()),
                    error: (e, st) => const CircleAvatar(
                        radius: 80, child: Icon(Icons.error)),
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
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
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
                        isSetupMode ? 'ยืนยันและเข้าสู่ระบบ' : 'เข้าสู่ระบบ',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
