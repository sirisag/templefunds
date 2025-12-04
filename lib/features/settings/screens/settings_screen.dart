import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/core/widgets/scroll_indicator_wrapper.dart';
import 'package:templefunds/core/widgets/navigation_tile.dart';
import 'package:templefunds/features/members/screens/change_pin_screen.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';
import 'package:templefunds/features/settings/screens/security_settings_screen.dart';
import 'package:templefunds/features/settings/widgets/theme_color_picker.dart';
import 'package:templefunds/features/home/widgets/home_image_customizer.dart';
import 'package:templefunds/features/settings/widgets/temple_avatar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _templeNameController = TextEditingController();
  final _exportPrefixController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  File? _pickedImageFile;
  File? _pickedLogoFile;

  bool _isTempleNameSaving = false;
  bool _isExportPrefixSaving = false;
  bool _isLogoSaving = false;
  bool _isBgLoading = false;
  double? _currentFontScale;

  @override
  void initState() {
    super.initState();
    // Pre-fill the text fields with existing data from providers
    final initialTempleName = ref.read(templeNameProvider).asData?.value;
    if (initialTempleName != null) {
      _templeNameController.text = initialTempleName;
    }
    final initialExportPrefix =
        ref.read(exportFilePrefixProvider).asData?.value;
    if (initialExportPrefix != null) {
      _exportPrefixController.text = initialExportPrefix;
    }
  }

  @override
  void dispose() {
    _templeNameController.dispose();
    _exportPrefixController.dispose();
    super.dispose();
  }

  // Generic helper to handle async settings updates
  Future<void> _handleUpdate({
    required Future<void> Function() updateFunction,
    required String successMessage,
    required void Function(bool) setLoading,
  }) async {
    if (!_formKey.currentState!.validate()) return;

    setLoading(true);
    try {
      await updateFunction();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      _showErrorSnackbar(e.toString());
    } finally {
      setLoading(false);
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);

    if (pickedFile != null && mounted) {
      final croppedFile = await ImageCropper.platform.cropImage(
        sourcePath: pickedFile.path,
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'ปรับแต่งโลโก้วัด',
            cropStyle: CropStyle.circle,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'ปรับแต่งโลโก้วัด',
            cropStyle: CropStyle.circle,
            aspectRatioLockEnabled: true,
          ),
        ],
      );
      if (croppedFile != null) {
        setState(() {
          _pickedLogoFile = File(croppedFile.path);
        });
      }
    }
  }

  Future<void> _pickAndSetBackground() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);

    if (pickedFile != null && mounted) {
      final croppedFile = await ImageCropper.platform.cropImage(
        sourcePath: pickedFile.path,
        compressQuality: 75,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'ปรับแต่งภาพพื้นหลัง',
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'ปรับแต่งภาพพื้นหลัง',
            aspectRatioLockEnabled: false,
          ),
        ],
      );
      if (croppedFile != null) {
        setState(() => _isBgLoading = true);
        await ref
            .read(backgroundStyleProvider.notifier)
            .updateBackgroundImage(File(croppedFile.path));
        if (mounted) {
          setState(() => _isBgLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('เปลี่ยนภาพพื้นหลังสำเร็จ'),
              backgroundColor: Colors.green));
        }
      }
    }
  }

  Future<void> _removeBackground() async {
    setState(() => _isBgLoading = true);
    await ref.read(backgroundStyleProvider.notifier).removeBackgroundImage();
    setState(() => _isBgLoading = false);
  }

  void _showErrorSnackbar(String error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('เกิดข้อผิดพลาด: $error'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use ref.watch to get the latest data and handle loading/error states
    final templeNameAsync = ref.watch(templeNameProvider);
    final exportPrefixAsync = ref.watch(exportFilePrefixProvider);

    // Set initial text only when data is available
    _templeNameController.text = templeNameAsync.asData?.value ?? '';
    _exportPrefixController.text = exportPrefixAsync.asData?.value ?? '';
    final fontScale = ref.watch(fontScaleProvider).asData?.value ?? 1.0;

    final isLoading = _isTempleNameSaving ||
        _isExportPrefixSaving ||
        _isLogoSaving ||
        _isBgLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าระบบ'),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ScrollIndicatorWrapper(
              builder: (context, scrollController) => ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
                children: [
                  NavigationTile(
                    icon: Icons.pin_outlined,
                    title: 'เปลี่ยนรหัส PIN',
                    subtitle: 'เปลี่ยนรหัส PIN 4 หลักสำหรับเข้าใช้งาน',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ChangePinScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  NavigationTile(
                    icon: Icons.fingerprint,
                    title: 'ความปลอดภัย',
                    subtitle: 'ตั้งค่าการเข้าสู่ระบบด้วยลายนิ้วมือ',
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const SecuritySettingsScreen()));
                    },
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('ตั้งค่าโลโก้วัด',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _pickLogo,
                            child: _pickedLogoFile != null
                                ? CircleAvatar(
                                    radius: 60,
                                    backgroundImage:
                                        FileImage(_pickedLogoFile!))
                                : const TempleAvatar(radius: 60),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _pickedLogoFile == null
                                ? null
                                : () => _handleUpdate(
                                      setLoading: (v) =>
                                          setState(() => _isLogoSaving = v),
                                      updateFunction: () => ref
                                          .read(settingsProvider.notifier)
                                          .updateTempleLogo(_pickedLogoFile!),
                                      successMessage: 'บันทึกโลโก้วัดสำเร็จ',
                                    ),
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('บันทึกโลโก้'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomizableHomeImage(pickedImageFile: _pickedImageFile),
                  ImageCustomizationControls(
                    isLoading: isLoading,
                    onImagePicked: (file) =>
                        setState(() => _pickedImageFile = file),
                    imageFile: _pickedImageFile,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _templeNameController,
                    decoration: InputDecoration(
                      labelText: 'ชื่อวัด',
                      border: const OutlineInputBorder(),
                      suffixIcon: _buildSaveButton(
                        isLoading: _isTempleNameSaving,
                        onPressed: () => _handleUpdate(
                          setLoading: (v) =>
                              setState(() => _isTempleNameSaving = v),
                          updateFunction: () => ref
                              .read(settingsProvider.notifier)
                              .updateTempleName(
                                  _templeNameController.text.trim()),
                          successMessage: 'เปลี่ยนชื่อวัดสำเร็จ',
                        ),
                        tooltip: 'บันทึกชื่อวัด',
                      ),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'ชื่อวัดต้องไม่ว่างเปล่า'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _exportPrefixController,
                    decoration: InputDecoration(
                      labelText: 'ชื่อไฟล์สำหรับส่งออก',
                      helperText: 'ใช้เป็นส่วนหน้าของชื่อไฟล์ตอนสำรองข้อมูล',
                      border: const OutlineInputBorder(),
                      suffixIcon: _buildSaveButton(
                        isLoading: _isExportPrefixSaving,
                        onPressed: () => _handleUpdate(
                          setLoading: (v) =>
                              setState(() => _isExportPrefixSaving = v),
                          updateFunction: () => ref
                              .read(settingsProvider.notifier)
                              .updateExportFilePrefix(
                                  _exportPrefixController.text.trim()),
                          successMessage: 'เปลี่ยนชื่อไฟล์ส่งออกสำเร็จ',
                        ),
                        tooltip: 'บันทึกชื่อไฟล์',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('เลือกธีมสีของแอป',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        children: [
                          const Text('ปรับขนาดตัวอักษร',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          Slider(
                            value: _currentFontScale ?? fontScale,
                            min: 0.8,
                            max: 1.4,
                            divisions: 6,
                            label:
                                'ขนาด ${((_currentFontScale ?? fontScale) * 100).toStringAsFixed(0)}%',
                            onChanged: (value) {
                              setState(() {
                                _currentFontScale = value;
                              });
                            },
                            onChangeEnd: (value) {
                              ref
                                  .read(fontScaleProvider.notifier)
                                  .updateFontScale(value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const ThemeColorPicker(),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  const Text('ปรับแต่งภาพพื้นหลังแอป',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (_isBgLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickAndSetBackground,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('เปลี่ยนภาพพื้นหลัง'),
                        ),
                        const SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: _removeBackground,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('ใช้ค่าเริ่มต้น'),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildSaveButton({
    required bool isLoading,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    return IconButton(
      icon: const Icon(Icons.save_outlined),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}
