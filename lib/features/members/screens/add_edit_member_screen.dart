import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:templefunds/core/utils/image_utils.dart';
import 'package:templefunds/core/models/user_model.dart';
import 'package:templefunds/features/transactions/providers/accounts_provider.dart';
import 'package:templefunds/core/services/crypto_service.dart';
import 'package:templefunds/features/members/providers/members_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class AddEditMemberScreen extends ConsumerStatefulWidget {
  final User? userToEdit; // Null for adding, not null for editing

  const AddEditMemberScreen({super.key, this.userToEdit});

  @override
  ConsumerState<AddEditMemberScreen> createState() =>
      _AddEditMemberScreenState();
}

class _AddEditMemberScreenState extends ConsumerState<AddEditMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  // New controllers for detailed user info
  final _nicknameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ordinationNameController = TextEditingController();
  final _specialTitleController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _id1Controller = TextEditingController();

  UserRole _selectedRole = UserRole.Monk; // Default role
  bool _isLoading = false;
  File? _profileImageFile;

  @override
  void initState() {
    super.initState();
    if (widget.userToEdit != null) {
      final user = widget.userToEdit!;
      _nicknameController.text = user.nickname;
      _firstNameController.text = user.firstName ?? '';
      _lastNameController.text = user.lastName ?? '';
      _ordinationNameController.text = user.ordinationName ?? '';
      _specialTitleController.text = user.specialTitle ?? '';
      _phoneNumberController.text = user.phoneNumber ?? '';
      _emailController.text = user.email ?? '';
      _id1Controller.text = user.userId1;
      _selectedRole = user.role;
      if (user.profileImage != null) {
        _profileImageFile = File(user.profileImage!);
      }
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ordinationNameController.dispose();
    _specialTitleController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    _id1Controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);

    if (pickedFile != null && mounted) {
      final croppedFile = await ImageCropper.platform.cropImage(
        sourcePath: pickedFile.path,
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'ปรับแต่งรูปภาพ',
            cropStyle: CropStyle.circle,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio:
                true, // For circle crop, aspect ratio is always 1:1
          ),
          IOSUiSettings(
            title: 'ปรับแต่งรูปภาพ',
            cropStyle: CropStyle.circle,
            aspectRatioLockEnabled: true,
          ),
        ],
      );
      if (croppedFile != null) {
        // To ensure the UI updates correctly, we save the resized image to a new unique path
        // instead of overwriting the same file, which can cause caching issues.
        final tempDir = await getTemporaryDirectory();
        final uniqueFileName = '${const Uuid().v4()}.jpg';
        final newPath = p.join(tempDir.path, uniqueFileName);
        final resizedImageFile = await ImageUtils.resizeImage(
          File(croppedFile.path),
          240,
          240,
          outputPath: newPath, // Pass the unique path to the resize function
        );
        setState(() => _profileImageFile = resizedImageFile);
      }
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.Admin:
        return 'ไวยาวัจกรณ์';
      case UserRole.Master:
        return 'เจ้าอาวาส';
      case UserRole.Monk:
        return 'พระลูกวัด';
    }
  }

  Future<void> _submitForm() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final notifier = ref.read(membersProvider.notifier);
    final nickname = _nicknameController.text.trim();
    final id1 = _id1Controller.text.trim();

    // Check for duplicate ID1
    final isId1Taken = await notifier.isUserId1Taken(id1,
        excludeUserId: widget.userToEdit?.id);
    if (isId1Taken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('รหัสประจำตัว "" นี้ถูกใช้งานแล้ว'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ), // This dialog is for changing nickname, should be replaced with a proper edit screen later
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    // Check for duplicate name and show warning
    final isNicknameTaken = await notifier.isNicknameTaken(nickname,
        excludeUserId: widget.userToEdit?.id);
    if (isNicknameTaken) {
      final continueAnyway = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('คำเตือน: ชื่อซ้ำ'),
              content: Text(
                  'มีสมาชิกชื่อเล่น "" อยู่ในระบบแล้ว คุณต้องการดำเนินการต่อหรือไม่?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('ยกเลิก')),
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('ดำเนินการต่อ')),
              ],
            ),
          ) ??
          false;

      if (!continueAnyway) {
        setState(() => _isLoading = false);
        return;
      }
    }

    String? newId2;
    if (widget.userToEdit == null) {
      // Only generate ID2 for new users
      newId2 = (1000 + Random().nextInt(9000)).toString();
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(widget.userToEdit == null
                ? 'ยืนยันการสร้างสมาชิก'
                : 'ยืนยันการแก้ไขข้อมูลสมาชิก'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.userToEdit == null
                    ? 'กรุณาตรวจสอบข้อมูลให้ถูกต้อง การกระทำนี้ไม่สามารถแก้ไขหรือลบได้ในภายหลัง'
                    : 'กรุณาตรวจสอบข้อมูลให้ถูกต้อง'),
                const Divider(),
                Text('ชื่อเล่น: $nickname'),
                if (_firstNameController.text.isNotEmpty)
                  Text('ชื่อจริง: ${_firstNameController.text.trim()}'),
                if (_lastNameController.text.isNotEmpty)
                  Text('นามสกุล: ${_lastNameController.text.trim()}'),
                if (_ordinationNameController.text
                    .isNotEmpty) // This dialog is for changing nickname, should be replaced with a proper edit screen later
                  Text('ฉายา: ${_ordinationNameController.text.trim()}'),
                Text('ID ชุดที่ 1: $id1'),
                if (newId2 != null) Text('ID ชุดที่ 2 (ระบบสร้าง): $newId2'),
                Text('บทบาท: ${_getRoleDisplayName(_selectedRole)}'),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('กลับไปแก้ไข')),
              ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('ยืนยันและบันทึก')),
            ],
          ),
        ) ??
        false; // This dialog is for changing nickname, should be replaced with a proper edit screen later

    if (confirmed) {
      String? profileImagePath;
      if (_profileImageFile != null) {
        // Delete the old image if it exists and we are picking a new one
        if (widget.userToEdit?.profileImage != null) {
          final oldFile = File(widget.userToEdit!.profileImage!);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        }

        final appDocsDir = await getApplicationDocumentsDirectory();
        final fileExtension = p.extension(_profileImageFile!.path);
        // Use a unique name to avoid caching issues
        final newFileName = 'profile_${const Uuid().v4()}$fileExtension';
        profileImagePath = p.join(appDocsDir.path, newFileName);
        await _profileImageFile!.copy(profileImagePath);
      } else if (widget.userToEdit != null) {
        // If in edit mode and no new image is picked, keep the old path.
        // If the user deleted their image, this will be null.
        profileImagePath = widget.userToEdit?.profileImage;
      }

      if (widget.userToEdit == null) {
        // Add new user
        final newUser = User(
          userId1: id1,
          userId2: ref.read(cryptoServiceProvider).hashString(newId2!),
          nickname: nickname,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          ordinationName: _ordinationNameController.text.trim(),
          specialTitle: _specialTitleController.text.trim(),
          phoneNumber: _phoneNumberController.text.trim(),
          email: _emailController.text.trim(),
          profileImage: profileImagePath,
          role: _selectedRole,
          createdAt: DateTime.now(),
        );
        await notifier.addUser(newUser);
      } else {
        // Update existing user
        final updatedUser = widget.userToEdit!.copyWith(
          nickname: nickname,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          ordinationName: _ordinationNameController.text.trim(),
          specialTitle: _specialTitleController.text.trim(),
          phoneNumber: _phoneNumberController.text.trim(),
          email: _emailController.text.trim(),
          profileImage: profileImagePath,
          role: _selectedRole,
        );
        await notifier.updateUserProfile(widget.userToEdit!.id!, updatedUser);
      }
      // Invalidate the accounts provider so the list is refreshed on the transaction screen
      ref.invalidate(allAccountsProvider);
      if (context.mounted) Navigator.of(context).pop();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine which image to display
    ImageProvider? imageProvider;
    if (_profileImageFile != null) {
      // A new image has been picked or an existing one was loaded
      imageProvider = FileImage(_profileImageFile!);
    } else if (widget.userToEdit?.profileImage != null &&
        File(widget.userToEdit!.profileImage!).existsSync()) {
      // This handles the case where initState hasn't run yet or the file was deleted externally
      imageProvider = FileImage(File(widget.userToEdit!.profileImage!));
    }

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.userToEdit == null
              ? 'เพิ่มสมาชิกใหม่'
              : 'แก้ไขข้อมูลส่วนตัว')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
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
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? Icon(Icons.add_a_photo_outlined,
                          size: 40, color: Colors.grey.shade700)
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                    labelText: 'ชื่อเล่น/ชื่อที่ใช้เรียก*',
                    prefixIcon: Icon(Icons.person_pin_circle_outlined)),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'กรุณากรอกชื่อเล่น'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                    labelText: 'ชื่อจริง',
                    prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                    labelText: 'นามสกุล',
                    prefixIcon: Icon(Icons.people_alt_outlined)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ordinationNameController,
                decoration: const InputDecoration(
                    labelText: 'ฉายา', prefixIcon: Icon(Icons.book_outlined)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _specialTitleController,
                decoration: const InputDecoration(
                    labelText: 'ยศ/สมณศักดิ์',
                    prefixIcon: Icon(Icons.star_border_outlined)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _id1Controller,
                decoration: const InputDecoration(
                    filled:
                        true, // Add a background color to indicate read-only
                    labelText: 'ID ประจำตัว (4 หลัก)*',
                    prefixIcon: Icon(Icons.badge_outlined)),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 4,
                validator: (v) =>
                    (v == null || v.length != 4) ? 'ต้องเป็นเลข 4 หลัก' : null,
                readOnly: widget.userToEdit != null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                value: _selectedRole,
                decoration: const InputDecoration(
                    labelText: 'บทบาท*',
                    prefixIcon: Icon(Icons.shield_outlined)),
                items: UserRole.values.map((role) {
                  return DropdownMenuItem<UserRole>(
                    value: role,
                    child: Text(_getRoleDisplayName(role)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedRole = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneNumberController,
                decoration: const InputDecoration(
                    labelText: 'เบอร์โทรศัพท์',
                    prefixIcon: Icon(Icons.phone_outlined)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                    labelText: 'อีเมล', prefixIcon: Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _submitForm,
                      icon: Icon(widget.userToEdit == null
                          ? Icons.person_add_alt_1
                          : Icons.save),
                      label: const Text('บันทึก'),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
