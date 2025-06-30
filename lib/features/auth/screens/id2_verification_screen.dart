import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class Id2VerificationScreen extends ConsumerStatefulWidget {
  const Id2VerificationScreen({super.key});

  @override
  ConsumerState<Id2VerificationScreen> createState() =>
      _Id2VerificationScreenState();
}

class _Id2VerificationScreenState extends ConsumerState<Id2VerificationScreen> {
  final _id2Controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
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

    await ref
        .read(authProvider.notifier)
        .verifyId2(_id2Controller.text.trim());

    // Navigation is handled by AuthWrapper.
    // If the ID2 is incorrect, the state will reset to loggedOut,
    // and the WelcomeScreen will show the error message.
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ยืนยันตัวตน'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'สวัสดี, ${user?.name ?? 'ผู้ใช้งาน'}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'กรุณากรอกรหัสยืนยันตัวตน (ID ชุดที่ 2) เพื่อดำเนินการต่อ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _id2Controller,
                  decoration: const InputDecoration(
                    labelText: 'รหัสยืนยันตัวตน (4 หลัก)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.password),
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
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('ยืนยัน'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 16),
                          textStyle: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}