import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/core/widgets/navigation_tile.dart';
import 'package:templefunds/core/widgets/scroll_indicator_wrapper.dart';
import 'package:templefunds/features/home/widgets/home_image_customizer.dart';
import 'package:templefunds/features/members/screens/change_pin_screen.dart';
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

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 24),
              const Text('เลือกธีมสีของแอป',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const ThemeColorPicker(),
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
