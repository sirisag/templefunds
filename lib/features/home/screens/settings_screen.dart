import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';
import 'package:templefunds/features/settings/widgets/theme_color_picker.dart';
import '../widgets/home_image_customizer.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final _templeNameController = TextEditingController();
  final _exportPrefixController = TextEditingController();

  File? _pickedImageFile;
  final _scrollController = ScrollController();

  bool _showScrollIndicator = false;
  late AnimationController _bounceAnimationController;
  late Animation<Offset> _bounceAnimation;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _bounceAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.15),
    ).animate(CurvedAnimation(
      parent: _bounceAnimationController,
      curve: Curves.easeInOut,
    ));

    _scrollController.addListener(_scrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Add a small delay to allow all async widgets to build and layout.
      await Future.delayed(const Duration(milliseconds: 100));

      if (!_scrollController.hasClients) return;

      // Programmatically scroll a tiny bit to trigger layout re-evaluation.
      final currentPixels = _scrollController.position.pixels;
      if (_scrollController.position.maxScrollExtent > 0) {
        _scrollController.jumpTo(currentPixels + 0.1);
        _scrollController.jumpTo(currentPixels - 0.1);
      }

      // One final check to ensure the state is updated.
      _scrollListener();
    });
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    bool shouldShow = _scrollController.position.maxScrollExtent > 0 &&
        _scrollController.position.pixels <
            _scrollController.position.maxScrollExtent;

    if (shouldShow != _showScrollIndicator) {
      setState(() {
        _showScrollIndicator = shouldShow;
      });
    }
  }

  @override
  void dispose() {
    _templeNameController.dispose();
    _exportPrefixController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _bounceAnimationController.dispose();
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

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<String?>>(templeNameProvider, (_, next) {
      final name = next.asData?.value;
      if (name != null && _templeNameController.text.isEmpty) {
        _templeNameController.text = name;
      }
    });
    ref.listen<AsyncValue<HomeStyleState>>(homeStyleProvider, (_, next) {
      final style = next.asData?.value;
      if (style != null && style.imagePath != null) {
        _pickedImageFile = File(style.imagePath!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าระบบ'),
      ),
      body: Stack(
        children: [
          ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
            children: [
              // 1. Image and Image Customization Menu
              CustomizableHomeImage(pickedImageFile: _pickedImageFile),
              ImageCustomizationControls(
                isLoading: _isLoading,
                onImagePicked: (file) {
                  setState(() {
                    _pickedImageFile = file;
                  });
                },
                imageFile: _pickedImageFile,
              ),
              const SizedBox(height: 24),

              // 2. Temple Name Change Menu
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

              // 3. Export File Name Change Menu
              TextFormField(
                controller: _exportPrefixController,
                decoration: InputDecoration(
                  labelText: 'ชื่อไฟล์สำหรับส่งออก',
                  helperText: 'ใช้เป็นส่วนหน้าของชื่อไฟล์ตอนสำรองข้อมูล',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.save_outlined),
                    onPressed: () {}, // This will be implemented later
                    tooltip: 'บันทึกชื่อไฟล์',
                  ),
                ),
                onFieldSubmitted: (_) {}, // This will be implemented later
              ),
              const SizedBox(height: 24),

              // 4. Theme Color Change Menu
              const Text('เลือกธีมสีของแอป',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const ThemeColorPicker(),
            ],
          ),
          // 5. Arrow Animation
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _showScrollIndicator ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                child: Center(
                  child: SlideTransition(
                    position: _bounceAnimation,
                    child: FloatingActionButton.small(
                      onPressed: null,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
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
