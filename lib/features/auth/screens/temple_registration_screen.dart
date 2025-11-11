import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:templefunds/core/models/user_model.dart';
import 'package:templefunds/features/home/screens/admin_home_screen.dart';
import 'package:templefunds/features/home/screens/master_home_screen.dart';
import 'package:templefunds/features/home/screens/member_home_screen.dart';
import '../providers/auth_provider.dart';

class TempleRegistrationScreen extends ConsumerStatefulWidget {
  const TempleRegistrationScreen({super.key});

  @override
  ConsumerState<TempleRegistrationScreen> createState() =>
      _TempleRegistrationScreenState();
}

class _TempleRegistrationScreenState
    extends ConsumerState<TempleRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _templeNameController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminId1Controller = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _isLoading = false;
  File? _logoImageFile;
  bool _isPinVisible = false;

  @override
  void dispose() {
    _templeNameController.dispose();
    _adminNameController.dispose();
    _adminId1Controller.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (pickedFile != null) {
      // After picking, open the cropper UI
      final croppedFile = await ImageCropper.platform.cropImage(
        sourcePath: pickedFile.path,
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'ปรับแต่งโลโก้',
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Colors.white,
            cropStyle: CropStyle.circle,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'ปรับแต่งโลโก้',
            cropStyle: CropStyle.circle,
            aspectRatioLockEnabled: true,
          ),
        ],
      );

      if (croppedFile == null) return; // User cancelled

      setState(() => _logoImageFile = File(croppedFile.path));
    }
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    // เราจะเรียกเมธอดใหม่ใน provider ที่จะจัดการการลงทะเบียนทั้งหมดในครั้งเดียว
    // (ซึ่งเราจะต้องสร้างเมธอดนี้ในขั้นตอนถัดไป)
    final newId2 = await ref.read(authProvider.notifier).registerNewTemple(
          templeName: _templeNameController.text.trim(),
          adminName: _adminNameController.text.trim(),
          adminId1: _adminId1Controller.text.trim(),
          pin: _pinController.text.trim(),
          logoImageFile: _logoImageFile,
        );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (newId2 != null) {
        // Registration was successful, show the ID2 to the user.
        // The AuthWrapper will handle navigation in the background.
        await showDialog(
          context: context,
          barrierDismissible: false, // User must acknowledge
          builder: (ctx) => AlertDialog(
            title: const Text('ลงทะเบียนสำเร็จ!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('รหัสยืนยันตัวตน (ID ชุดที่ 2) ของคุณคือ:'),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    newId2,
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('กรุณาจดจำรหัสนี้ไว้สำหรับเข้าสู่ระบบในครั้งถัดไป',
                    style: TextStyle(color: Colors.red)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();

                  final authState = ref.read(authProvider);
                  final user = authState.user;
                  Widget homeScreen;
                  if (user?.role == UserRole.Admin) {
                    homeScreen = const AdminHomeScreen();
                  } else if (user?.role == UserRole.Master) {
                    homeScreen = const MasterHomeScreen();
                  } else {
                    homeScreen = const MemberHomeScreen();
                  }

                  // After acknowledging, clear the entire stack and push the home screen.
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => homeScreen),
                    (route) => false,
                  );
                },
                child: const Text('รับทราบและเข้าสู่ระบบ'),
              ),
            ],
          ),
        );
      }
      // If newId2 is null, an error dialog will be shown by the listener in WelcomeScreen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ลงทะเบียนวัดและผู้ดูแล')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _logoImageFile != null
                      ? FileImage(_logoImageFile!)
                      : null,
                  child: _logoImageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 40,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'เลือกโลโก้วัด',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _templeNameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อวัด',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อวัด' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adminNameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อไวยาวัจกรณ์ (ผู้ดูแล)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'กรุณากรอกชื่อผู้ดูแล'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adminId1Controller,
                decoration: const InputDecoration(
                  labelText: 'ID ประจำตัวผู้ดูแล (4 หลัก)',
                  prefixIcon: Icon(Icons.badge_outlined),
                  counterText: "",
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 4,
                validator: (v) =>
                    (v == null || v.length != 4) ? 'ต้องเป็นเลข 4 หลัก' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pinController,
                decoration: InputDecoration(
                  labelText: 'ตั้งรหัส PIN เริ่มต้น (4 หลัก)',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  counterText: "",
                  suffixIcon: IconButton(
                    icon: Icon(_isPinVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _isPinVisible = !_isPinVisible),
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 4,
                obscureText: !_isPinVisible,
                validator: (v) =>
                    (v == null || v.length != 4) ? 'ต้องเป็นเลข 4 หลัก' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPinController,
                decoration: const InputDecoration(
                  labelText: 'ยืนยันรหัส PIN',
                  prefixIcon: Icon(Icons.pin_outlined),
                  counterText: "",
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 4,
                obscureText: !_isPinVisible,
                validator: (v) {
                  if (v != _pinController.text) {
                    return 'รหัส PIN ไม่ตรงกัน';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.app_registration),
                      label: const Text('ลงทะเบียนและสร้างฐานข้อมูล'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
