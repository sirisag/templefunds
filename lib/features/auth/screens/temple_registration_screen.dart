import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:templefunds/core/models/user_model.dart';
import 'package:templefunds/features/home/screens/admin_home_screen.dart';
import 'package:templefunds/features/home/screens/master_home_screen.dart';
import 'package:templefunds/features/home/screens/member_home_screen.dart';
import '../widgets/pin_form_field.dart';
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
  // New controllers for detailed admin user info
  final _adminNicknameController = TextEditingController();
  final _adminFirstNameController = TextEditingController();
  final _adminLastNameController = TextEditingController();
  final _adminOrdinationNameController = TextEditingController();
  final _adminSpecialTitleController = TextEditingController();
  final _adminPhoneNumberController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminId1Controller = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _isLoading = false;
  File? _logoImageFile;
  File? _adminProfileImageFile; // New: for admin's profile image
  bool _isPinVisible = false;

  @override
  void dispose() {
    _templeNameController.dispose();
    _adminNicknameController.dispose();
    _adminFirstNameController.dispose();
    _adminLastNameController.dispose();
    _adminOrdinationNameController.dispose();
    _adminSpecialTitleController.dispose();
    _adminPhoneNumberController.dispose();
    _adminEmailController.dispose();
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

  // New method for picking admin's profile image
  Future<void> _pickAdminProfileImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);

    if (pickedFile != null && mounted) {
      final croppedFile = await ImageCropper.platform.cropImage(
        sourcePath: pickedFile.path,
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'ปรับแต่งรูปภาพผู้ดูแล',
            cropStyle: CropStyle.circle,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
              title: 'ปรับแต่งรูปภาพผู้ดูแล',
              cropStyle: CropStyle.circle,
              aspectRatioLockEnabled: true),
        ],
      );
      if (croppedFile != null)
        setState(() => _adminProfileImageFile = File(croppedFile.path));
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
          nickname: _adminNicknameController.text.trim(),
          firstName: _adminFirstNameController.text.trim(),
          lastName: _adminLastNameController.text.trim(),
          ordinationName: _adminOrdinationNameController.text.trim(),
          specialTitle: _adminSpecialTitleController.text.trim(),
          phoneNumber: _adminPhoneNumberController.text.trim(),
          email: _adminEmailController.text.trim(),
          adminId1: _adminId1Controller.text.trim(),
          pin: _pinController.text.trim(),
          logoImageFile: _logoImageFile,
          adminProfileImageFile: _adminProfileImageFile,
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
              // Admin Profile Image Picker
              GestureDetector(
                onTap: _pickAdminProfileImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _adminProfileImageFile != null
                      ? FileImage(_adminProfileImageFile!)
                      : null,
                  child: _adminProfileImageFile == null
                      ? Icon(Icons.add_a_photo_outlined,
                          size: 40, color: Colors.grey.shade600)
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _adminNicknameController,
                decoration: const InputDecoration(
                    labelText: 'ชื่อเล่น/ชื่อที่ใช้เรียก (ผู้ดูแล)*',
                    prefixIcon: Icon(Icons.person_pin_circle_outlined)),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'กรุณากรอกชื่อเล่นผู้ดูแล'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adminFirstNameController,
                decoration: const InputDecoration(
                    labelText: 'ชื่อจริง (ผู้ดูแล)',
                    prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adminLastNameController,
                decoration: const InputDecoration(
                    labelText: 'นามสกุล (ผู้ดูแล)',
                    prefixIcon: Icon(Icons.people_alt_outlined)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adminOrdinationNameController,
                decoration: const InputDecoration(
                    labelText: 'ฉายา (ผู้ดูแล)',
                    prefixIcon: Icon(Icons.book_outlined)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adminSpecialTitleController,
                decoration: const InputDecoration(
                    labelText: 'ยศ/สมณศักดิ์ (ผู้ดูแล)',
                    prefixIcon: Icon(Icons.star_border_outlined)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adminPhoneNumberController,
                decoration: const InputDecoration(
                    labelText: 'เบอร์โทรศัพท์ (ผู้ดูแล)',
                    prefixIcon: Icon(Icons.phone_outlined)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adminEmailController,
                decoration: const InputDecoration(
                    labelText: 'อีเมล (ผู้ดูแล)',
                    prefixIcon: Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adminId1Controller,
                decoration: const InputDecoration(
                  labelText: 'ID ประจำตัวผู้ดูแล (4 หลัก)*',
                  prefixIcon: Icon(Icons.badge_outlined),
                  counterText: "",
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 4,
                validator: (v) =>
                    (v == null || v.length != 4) ? 'ต้องเป็นเลข 4 หลัก' : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 16),
              PinFormField(
                controller: _pinController,
                labelText: 'ตั้งรหัส PIN เริ่มต้น (4 หลัก)*',
                isPinVisible: _isPinVisible,
              ),
              const SizedBox(height: 16),
              PinFormField(
                controller: _confirmPinController,
                labelText: 'ยืนยันรหัส PIN*',
                isPinVisible: _isPinVisible,
                validator: (v) {
                  if (v == null || v.trim().length != 4) {
                    return 'กรุณากรอกรหัส PIN 4 หลัก';
                  }
                  if (v != _pinController.text) {
                    return 'รหัส PIN ไม่ตรงกัน';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _isPinVisible = !_isPinVisible),
                  icon: Icon(
                      _isPinVisible ? Icons.visibility_off : Icons.visibility),
                  label: Text(_isPinVisible ? 'ซ่อนรหัส' : 'แสดงรหัส'),
                ),
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
