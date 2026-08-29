# Flutter Local Notifications Plugin ProGuard Rules
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class com.google.gson.** { *; }
-keep class com.google.crypto.tink.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-dontwarn com.dexterous.flutterlocalnotifications.**

# Flutter Framework & Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Desugaring
-dontwarn java.time.**
