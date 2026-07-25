// ✅ CRITICAL: Required imports for signing configuration
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.certstudytracker.study"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // flutter_local_notifications 요구사항: core library desugaring 활성화
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.certstudytracker.study"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // 상용화: 코드 난독화 + 미사용 리소스 제거로 APK 경량화 & 리버스 방어
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // R59: 학습앱(user)과 관리자앱(admin)을 하나의 코드베이스에서 분리 빌드.
    //   - user  : 기본 학습앱(applicationId 유지)
    //   - admin : 관리자 콘솔 앱(.admin 접미사 → 한 기기에 둘 다 설치 가능)
    // 관리자 APK 빌드: flutter build apk --release --flavor admin -t lib/main_admin.dart
    flavorDimensions += "app"
    productFlavors {
        create("user") {
            dimension = "app"
            // applicationId 유지(com.certstudytracker.study)
        }
        create("admin") {
            dimension = "app"
            applicationIdSuffix = ".admin"
            resValue("string", "app_name", "Gisaclub 관리자")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // flutter_local_notifications core library desugaring 의존성
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
