import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';

class ThemeColorPicker extends ConsumerWidget {
  const ThemeColorPicker({super.key});

  // Map of color names (for storage) to Color objects (for display)
  static const Map<String, Color> _availableColors = {
    'deepOrange': Colors.deepOrange,
    'blue': Colors.blue,
    'green': Colors.green,
    'purple': Colors.purple,
    'teal': Colors.teal,
    'brown': Colors.brown,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeColorName =
        ref.watch(themeSeedColorProvider).asData?.value ?? 'deepOrange';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 16.0,
          runSpacing: 16.0,
          alignment: WrapAlignment.center,
          children: _availableColors.entries.map((entry) {
            final colorName = entry.key;
            final colorValue = entry.value;
            final isSelected = colorName == currentThemeColorName;

            return InkWell(
              onTap: () async {
                if (!isSelected) {
                  await ref
                      .read(settingsProvider.notifier)
                      .updateThemeColor(colorName);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('เปลี่ยนธีมสีสำเร็จ'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(25),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: colorValue,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3,
                        )
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
