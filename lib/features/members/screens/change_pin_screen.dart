import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';

class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmNewPinController = TextEditingController();
  bool _isLoading = false;
  bool _isPinVisible = false;

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmNewPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).changePin(
            _oldPinController.text.trim(),
            _newPinController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เปลี่ยนรหัส PIN สำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst("Exception: ", "")),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เปลี่ยนรหัส PIN'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPinField(
                controller: _oldPinController,
                labelText: 'รหัส PIN ปัจจุบัน',
              ),
              const SizedBox(height: 16),
              _buildPinField(
                controller: _newPinController,
                labelText: 'รหัส PIN ใหม่',
                validator: (v) {
                  if (v == _oldPinController.text) {
                    return 'รหัสใหม่ต้องไม่ซ้ำรหัสเดิม';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildPinField(
                controller: _confirmNewPinController,
                labelText: 'ยืนยันรหัส PIN ใหม่',
                validator: (v) {
                  if (v != _newPinController.text) return 'รหัส PIN ไม่ตรงกัน';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.save),
                      label: const Text('บันทึกการเปลี่ยนแปลง'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required String labelText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        counterText: '',
        suffixIcon: IconButton(
          icon: Icon(_isPinVisible ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _isPinVisible = !_isPinVisible),
        ),
      ),
      maxLength: 4,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      obscureText: !_isPinVisible,
      validator: (v) {
        if ((v?.length ?? 0) != 4) return 'ต้องเป็นเลข 4 หลัก';
        return validator?.call(v);
      },
    );
  }
}