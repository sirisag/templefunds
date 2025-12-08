import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:templefunds/core/database/database_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';

/// A provider to fetch the temple name from the database.
/// It will be cached and only re-fetched when invalidated.
final templeNameProvider = FutureProvider<String?>((ref) async {
  // This provider does not need to be autoDispose because the temple name
  // is unlikely to change during a session.
  final dbHelper = DatabaseHelper.instance;
  return dbHelper.getAppMetadata('temple_name');
});

/// A provider to fetch the export file name prefix from the database.
final exportFilePrefixProvider = FutureProvider<String?>((ref) async {
  final dbHelper = DatabaseHelper.instance;
  return dbHelper.getAppMetadata('export_file_prefix');
});

/// A provider to fetch the saved theme seed color name from the database.
final themeSeedColorProvider = FutureProvider<String?>((ref) async {
  final dbHelper = DatabaseHelper.instance;
  return dbHelper.getAppMetadata('theme_seed_color');
});

/// A provider to fetch the saved temple logo path from the database.
final templeLogoProvider = FutureProvider<String?>((ref) async {
  final dbHelper = DatabaseHelper.instance;
  return dbHelper.getAppMetadata('temple_logo_path');
});

/// A provider to fetch the backup reminder period in days.
final backupReminderDaysProvider = FutureProvider<int>((ref) async {
  final dbHelper = DatabaseHelper.instance;
  final daysString = await dbHelper.getAppMetadata('backup_reminder_days');
  // Default to 7 days if not set.
  return int.tryParse(daysString ?? '7') ?? 7;
});

/// Notifier for handling settings updates.
class SettingsNotifier extends Notifier<AsyncValue<void>> {
  late DatabaseHelper _dbHelper;

  @override
  AsyncValue<void> build() {
    _dbHelper = DatabaseHelper.instance;
    return const AsyncValue.data(null);
  }

  Future<void> updateTempleName(String newName) async {
    state = const AsyncValue.loading();
    try {
      await _dbHelper.setAppMetadata('temple_name', newName);
      ref.invalidate(templeNameProvider); // Force refresh
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> updateExportFilePrefix(String newPrefix) async {
    state = const AsyncValue.loading();
    try {
      await _dbHelper.setAppMetadata('export_file_prefix', newPrefix);
      ref.invalidate(exportFilePrefixProvider); // Force refresh
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> updateThemeColor(String colorName) async {
    state = const AsyncValue.loading();
    try {
      await _dbHelper.setAppMetadata('theme_seed_color', colorName);
      ref.invalidate(themeSeedColorProvider); // Force refresh
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> updateTempleLogo(File logoFile) async {
    state = const AsyncValue.loading();
    try {
      // Save the image to a permanent location in the app's documents directory
      final appDocsDir = await getApplicationDocumentsDirectory();
      final fileExtension = p.extension(logoFile.path);
      final newFileName = 'temple_logo$fileExtension';
      final newPath = p.join(appDocsDir.path, newFileName);

      // Copy the picked file to the new path
      await logoFile.copy(newPath);

      await _dbHelper.setAppMetadata('temple_logo_path', newPath);
      ref.invalidate(templeLogoProvider); // Force refresh
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> updateBackupReminderDays(int days) async {
    state = const AsyncValue.loading();
    try {
      await _dbHelper.setAppMetadata('backup_reminder_days', days.toString());
      ref.invalidate(backupReminderDaysProvider); // Force refresh
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }
}

/// Provider for the SettingsNotifier.
final settingsProvider =
    NotifierProvider<SettingsNotifier, AsyncValue<void>>(() {
  return SettingsNotifier();
});

// --- Biometric Settings Provider ---

class BiometricSettingsNotifier extends AsyncNotifier<bool> {
  static const _biometricEnabledKey = 'biometric_enabled';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  Future<void> setBiometricEnabled(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await prefs.setBool(_biometricEnabledKey, isEnabled);
      return isEnabled;
    });
  }
}

final biometricSettingsProvider =
    AsyncNotifierProvider<BiometricSettingsNotifier, bool>(() {
  return BiometricSettingsNotifier();
});
// --- Local Device Customization Providers ---

@immutable
class HomeStyleState {
  final String? imagePath; // Custom home screen image
  final double cornerRadius;
  final double widthMultiplier;
  final double heightMultiplier;

  const HomeStyleState({
    this.imagePath,
    this.cornerRadius = 150.0, // <-- 1. แก้ไขค่าเริ่มต้นความโค้งที่นี่
    this.widthMultiplier = 0.78, // <-- 2. แก้ไขค่าเริ่มต้นความกว้างที่นี่
    this.heightMultiplier = 0.7, // <-- 3. แก้ไขค่าเริ่มต้นความสูงที่นี่
  });

  HomeStyleState copyWith({
    String? imagePath,
    double? cornerRadius,
    double? widthMultiplier,
    double? heightMultiplier,
  }) {
    return HomeStyleState(
      imagePath: imagePath ?? this.imagePath,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      widthMultiplier: widthMultiplier ?? this.widthMultiplier,
      heightMultiplier: heightMultiplier ?? this.heightMultiplier,
    );
  }
}

class HomeStyleNotifier extends AsyncNotifier<HomeStyleState> {
  static const _pathKey = 'home_style_image_path';
  static const _radiusKey = 'home_style_corner_radius';
  static const _widthKey = 'home_style_width';
  static const _heightKey = 'home_style_height';

  @override
  Future<HomeStyleState> build() async {
    final prefs = await SharedPreferences.getInstance();
    const defaultStyle = HomeStyleState();
    return HomeStyleState(
      imagePath: prefs.getString(_pathKey),
      cornerRadius: prefs.getDouble(_radiusKey) ?? defaultStyle.cornerRadius,
      widthMultiplier:
          prefs.getDouble(_widthKey) ?? defaultStyle.widthMultiplier,
      heightMultiplier:
          prefs.getDouble(_heightKey) ?? defaultStyle.heightMultiplier,
    );
  }

  Future<void> updateAndSaveStyle({
    File? imageFile,
    double? cornerRadius,
    double? width,
    double? height,
  }) async {
    final currentState = state.asData?.value ?? const HomeStyleState();

    String? newImagePath = currentState.imagePath;

    if (imageFile != null) {
      final appDocsDir = await getApplicationDocumentsDirectory();
      newImagePath = p.join(appDocsDir.path, 'home_screen_custom_image.png');
      await imageFile.copy(newImagePath); // <--- เพิ่มบรรทัดนี้กลับเข้ามา
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pathKey, newImagePath);
    }

    state = AsyncValue.data(currentState.copyWith(
        imagePath: newImagePath,
        cornerRadius: cornerRadius,
        widthMultiplier: width,
        heightMultiplier: height));

    final prefs = await SharedPreferences.getInstance();
    if (cornerRadius != null) await prefs.setDouble(_radiusKey, cornerRadius);
    if (width != null) await prefs.setDouble(_widthKey, width);
    if (height != null) await prefs.setDouble(_heightKey, height);
  }
}

final homeStyleProvider =
    AsyncNotifierProvider<HomeStyleNotifier, HomeStyleState>(() {
  return HomeStyleNotifier();
});

// --- Background Image Provider ---

@immutable
class BackgroundStyleState {
  final String? imagePath;

  const BackgroundStyleState({this.imagePath});
}

class BackgroundStyleNotifier extends AsyncNotifier<BackgroundStyleState> {
  static const _pathKey = 'background_style_image_path';

  @override
  Future<BackgroundStyleState> build() async {
    final prefs = await SharedPreferences.getInstance();
    return BackgroundStyleState(imagePath: prefs.getString(_pathKey));
  }

  Future<void> updateBackgroundImage(File imageFile) async {
    final appDocsDir = await getApplicationDocumentsDirectory();
    final newImagePath = p.join(appDocsDir.path, 'app_background_image.png');
    await imageFile.copy(newImagePath);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pathKey, newImagePath);

    state = AsyncValue.data(BackgroundStyleState(imagePath: newImagePath));
  }

  Future<void> removeBackgroundImage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pathKey);
    state = const AsyncValue.data(BackgroundStyleState(imagePath: null));
  }
}

final backgroundStyleProvider =
    AsyncNotifierProvider<BackgroundStyleNotifier, BackgroundStyleState>(() {
  return BackgroundStyleNotifier();
});

// --- Font Scale Provider ---

class FontScaleNotifier extends AsyncNotifier<double> {
  static const _fontScaleKey = 'app_font_scale';

  @override
  Future<double> build() async {
    final prefs = await SharedPreferences.getInstance();
    // Default scale is 1.0
    return prefs.getDouble(_fontScaleKey) ?? 1.0;
  }

  Future<void> updateFontScale(double newScale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontScaleKey, newScale);
    state = AsyncValue.data(newScale);
  }
}

final fontScaleProvider = AsyncNotifierProvider<FontScaleNotifier, double>(() {
  return FontScaleNotifier();
});
