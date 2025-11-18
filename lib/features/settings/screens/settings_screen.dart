import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/core/widgets/scroll_indicator_wrapper.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';
import 'package:templefunds/features/settings/widgets/theme_color_picker.dart';
import 'package:templefunds/features/home/widgets/home_image_customizer.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _templeNameController = TextEditingController();
  final _exportPrefixController = TextEditingController();

  File? _pickedImageFile;

  bool _isLoading = false;

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

  Future<void> _updateTempleName() async {
    final newName = _templeNameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ชื่อวัดต้องไม่ว่างเปล่า')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(settingsProvider.notifier).updateTempleName(newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เปลี่ยนชื่อวัดสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateExportPrefix() async {
    final newPrefix = _exportPrefixController.text.trim();
    setState(() => _isLoading = true);
    try {
      await ref
          .read(settingsProvider.notifier)
          .updateExportFilePrefix(newPrefix);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เปลี่ยนชื่อไฟล์ส่งออกสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for provider changes to update text fields if needed
    ref.listen<AsyncValue<String?>>(templeNameProvider, (_, next) {
      final name = next.asData?.value;
      if (name != null && _templeNameController.text != name) {
        _templeNameController.text = name;
      }
    });
    ref.listen<AsyncValue<String?>>(exportFilePrefixProvider, (_, next) {
      final prefix = next.asData?.value;
      if (prefix != null && _exportPrefixController.text != prefix) {
        _exportPrefixController.text = prefix;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าระบบ'),
      ),
      body: Stack(
        children: [
          ScrollIndicatorWrapper(
            builder: (context, scrollController) => ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
              children: [
                CustomizableHomeImage(pickedImageFile: _pickedImageFile),
                ImageCustomizationControls(
                  isLoading: _isLoading,
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
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.save_outlined),
                      onPressed: _updateTempleName,
                      tooltip: 'บันทึกชื่อวัด',
                    ),
                  ),
                  onFieldSubmitted: (_) => _updateTempleName(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _exportPrefixController,
                  decoration: InputDecoration(
                    labelText: 'ชื่อไฟล์สำหรับส่งออก',
                    helperText: 'ใช้เป็นส่วนหน้าของชื่อไฟล์ตอนสำรองข้อมูล',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.save_outlined),
                      onPressed: _updateExportPrefix,
                      tooltip: 'บันทึกชื่อไฟล์',
                    ),
                  ),
                  onFieldSubmitted: (_) => _updateExportPrefix(),
                ),
                const SizedBox(height: 24),
                const Text('เลือกธีมสีของแอป',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const ThemeColorPicker(),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
