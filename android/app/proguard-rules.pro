# ============================================================
# gisaclub ProGuard/R8 규칙 (상용화 릴리스 빌드)
# 코드 난독화 + 리소스 축소 시 플러그인이 깨지지 않도록 keep
# ============================================================

# ---- Flutter 엔진 ----
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ---- flutter_local_notifications (예약 알림/부팅 리시버 리플렉션) ----
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.**

# 알림에 GSON을 사용하므로 제네릭/직렬화 관련 keep
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ---- speech_to_text / flutter_tts (음성 인식·합성) ----
-keep class android.speech.** { *; }
-dontwarn android.speech.**

# ---- Play Core (Deferred Components 경고 억제) ----
-dontwarn com.google.android.play.core.**

# ---- 일반: 네이티브 메서드·열거형·Parcelable 보존 ----
-keepclasseswithmembernames class * {
    native <methods>;
}
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# 라인 번호 유지(크래시 리포트 스택트레이스 가독성)
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
