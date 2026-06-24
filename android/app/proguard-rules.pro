# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Mobile Ads (AdMob) + UMP consent
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }
-dontwarn com.google.android.gms.ads.**

# Firebase (Core, Remote Config, Crashlytics)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
# Keep Crashlytics line numbers / source file for readable stack traces
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Google Play Billing (in_app_purchase)
-keep class com.android.billingclient.api.** { *; }
-keep class io.flutter.plugins.inapppurchase.** { *; }

# Play Core (deferred components / split install referenced by Flutter)
-dontwarn com.google.android.play.core.**
