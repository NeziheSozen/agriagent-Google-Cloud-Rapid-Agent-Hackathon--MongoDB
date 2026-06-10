# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# MediaPipe (fixes missing classes during minifyReleaseWithR8)
-dontwarn com.google.mediapipe.**
-keep class com.google.mediapipe.** { *; }

# General
-dontwarn android.hardware.**
-dontwarn android.support.**
-dontwarn androidx.**
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
