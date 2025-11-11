import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';

/// A reusable widget that displays the customizable home screen image.
class CustomizableHomeImage extends ConsumerWidget {
  final File? pickedImageFile;

  const CustomizableHomeImage({super.key, this.pickedImageFile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeStyleAsync = ref.watch(homeStyleProvider);

    return homeStyleAsync.when(
      data: (style) {
        ImageProvider imageProvider;
        if (pickedImageFile != null) {
          imageProvider = FileImage(pickedImageFile!);
        } else if (style.imagePath != null &&
            File(style.imagePath!).existsSync()) {
          imageProvider = FileImage(File(style.imagePath!));
        } else {
          imageProvider = const AssetImage('assets/icon/icon.png');
        }

        final horizontalPadding = (1 - style.widthMultiplier) / 2;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.of(context).size.width * horizontalPadding,
            8,
            MediaQuery.of(context).size.width * horizontalPadding,
            16,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(style.cornerRadius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Container(
                width:
                    MediaQuery.of(context).size.width * style.widthMultiplier,
                height:
                    MediaQuery.of(context).size.width * style.heightMultiplier,
                decoration: BoxDecoration(
                  image:
                      DecorationImage(fit: BoxFit.cover, image: imageProvider),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
    );
  }
}

/// A reusable widget containing controls for customizing the home screen image.
class ImageCustomizationControls extends ConsumerStatefulWidget {
  final Function(File) onImagePicked;
  final File? imageFile;
  final bool isLoading;

  const ImageCustomizationControls({
    super.key,
    required this.onImagePicked,
    this.imageFile,
    required this.isLoading,
  });

  @override
  ConsumerState<ImageCustomizationControls> createState() =>
      _ImageCustomizationControlsState();
}

class _ImageCustomizationControlsState
    extends ConsumerState<ImageCustomizationControls> {
  late double _cornerRadius;
  late double _width;
  late double _height;

  @override
  void initState() {
    super.initState();
    final initialStyle =
        ref.read(homeStyleProvider).asData?.value ?? const HomeStyleState();
    _cornerRadius = initialStyle.cornerRadius;
    _width = initialStyle.widthMultiplier;
    _height = initialStyle.heightMultiplier;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (pickedFile != null && mounted) {
      final croppedFile = await ImageCropper.platform.cropImage(
        sourcePath: pickedFile.path,
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'ปรับแต่งรูปภาพ',
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'ปรับแต่งรูปภาพ',
            aspectRatioLockEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        widget.onImagePicked(File(croppedFile.path));
      }
    }
  }

  Future<void> _saveCustomization() async {
    await ref.read(homeStyleProvider.notifier).updateAndSaveStyle(
          cornerRadius: _cornerRadius,
          width: _width,
          height: _height,
          imageFile: widget.imageFile,
        );
  }

  void _syncStateWithProvider(HomeStyleState style) {
    // Helper method to update the local state from the provider's state.
    // This is called from initState and didUpdateWidget.
    setState(() {
      print(
          "Syncing with provider: cornerRadius=${style.cornerRadius}, width=${style.widthMultiplier}, height=${style.heightMultiplier}");
      _cornerRadius = style.cornerRadius;
      _width = style.widthMultiplier;
      _height = style.heightMultiplier;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('ปรับแต่งรูปภาพหน้าหลัก',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_search),
              label: const Text('เลือกรูปภาพใหม่'),
            ),
            _buildSlider('ความโค้ง', _cornerRadius, 0, 100,
                (v) => setState(() => _cornerRadius = v)),
            _buildSlider('ความกว้าง', _width, 0.2, 1.0,
                (v) => setState(() => _width = v)),
            _buildSlider('ความสูง', _height, 0.2, 1.0,
                (v) => setState(() => _height = v)),
            const SizedBox(height: 16),
            widget.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: () async {
                      // We only save the slider values here.
                      // The image file is now also handled here.
                      await _saveCustomization();
                      if (mounted) {
                        final message = widget.imageFile != null
                            ? 'บันทึกรูปภาพและสไตล์สำเร็จ'
                            : 'บันทึกขนาดและรูปทรงสำเร็จ';

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('บันทึกขนาด/รูปทรง'),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: 100,
            label: value.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
