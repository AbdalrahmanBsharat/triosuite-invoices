# R8 rules for the release build.
#
# Flutter itself needs no rules — the engine is native and the Dart code is AOT-compiled — but two
# plugins reach Java classes reflectively, so R8 has no way to see that they are used.

# mobile_scanner delegates to ML Kit's barcode scanner, which is loaded reflectively.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.mlkit.**

# ML Kit's optional text-recognition models are not bundled; silence the references to them.
-dontwarn com.google.android.gms.**

# flutter_secure_storage uses the AndroidX security library, which reflects over Tink.
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
