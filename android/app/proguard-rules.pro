# Flutter wrapper rules.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Rules for image_cropper (uCrop) and its dependency OkHttp.
# This prevents R8 from removing classes needed for image cropping in release builds.
-keep class com.yalantis.ucrop.** { *; }
-keep interface com.yalantis.ucrop.** { *; }
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Rules for Google Play Core library, used by Flutter for deferred components.
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }