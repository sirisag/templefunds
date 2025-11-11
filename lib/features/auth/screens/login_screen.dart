import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';
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

  @override
  void dispose() {
    _id1Controller.dispose();
    _id2Controller.dispose();
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

    await ref.read(authProvider.notifier).loginWithIds(
          id1: _id1Controller.text.trim(),
          id2: _id2Controller.text.trim(),
        );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (ref.read(authProvider).status == AuthStatus.requiresPinSetup) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PinScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      }
    });

    final homeStyleAsync = ref.watch(homeStyleProvider);

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
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.login),
                        label: const Text('เข้าสู่ระบบ'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
