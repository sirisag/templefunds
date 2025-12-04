import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/core/widgets/navigation_tile.dart';
import 'package:templefunds/core/widgets/scroll_indicator_wrapper.dart';
import 'package:templefunds/features/home/widgets/home_image_customizer.dart';
import 'package:templefunds/features/members/screens/change_pin_screen.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';
import 'package:templefunds/features/settings/screens/security_settings_screen.dart';
import 'package:templefunds/features/settings/widgets/theme_color_picker.dart';

class PersonalSettingsScreen extends ConsumerStatefulWidget {
  const PersonalSettingsScreen({super.key});

  @override
  ConsumerState<PersonalSettingsScreen> createState() =>
      _PersonalSettingsScreenState();
}

class _PersonalSettingsScreenState
    extends ConsumerState<PersonalSettingsScreen> {
  File? _pickedImageFile;
  bool _isLoading = false;
  bool _isBgLoading = false;
  double? _currentFontScale;

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

  @override
  Widget build(BuildContext context) {
    final fontScale = ref.watch(fontScaleProvider).asData?.value ?? 1.0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าส่วนตัว'),
      ),
      body: ScrollIndicatorWrapper(
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
            children: [
              NavigationTile(
                icon: Icons.pin_outlined,
                title: 'เปลี่ยนรหัส PIN',
                subtitle: 'เปลี่ยนรหัส PIN 4 หลักสำหรับเข้าใช้งาน',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChangePinScreen()),
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
              const SizedBox(height: 24),
              const Text('เลือกธีมสีของแอป',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const ThemeColorPicker(),
              const SizedBox(height: 24),
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
              const Divider(),
              const SizedBox(height: 24),
              const Text('ปรับแต่งภาพพื้นหลังแอป',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              CustomizableHomeImage(pickedImageFile: _pickedImageFile),
              ImageCustomizationControls(
                isLoading: _isLoading,
                onImagePicked: (file) =>
                    setState(() => _pickedImageFile = file),
                imageFile: _pickedImageFile,
              ),
            ],
          );
        },
      ),
    );
  }
}
