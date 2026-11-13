import java.util.Properties
import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val projectSigningFile = rootProject.file("signing/credentials.properties")
check(projectSigningFile.exists()) { "Project signing configuration is missing; recover the fixed identity from Vault." }
val projectSigning = Properties().apply { projectSigningFile.inputStream().use { load(it) } }
val fridgeDartDefines = (project.findProperty("dart-defines") as? String).orEmpty()
    .split(',').filter { it.isNotBlank() }.associate {
        val pair = String(Base64.getDecoder().decode(it)).split('=', limit = 2)
        pair[0] to pair.getOrElse(1) { "" }
    }

android {
    namespace = "com.fenlengtech.fridge"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.14206865"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        manifestPlaceholders["fridgeWechatAppId"] = fridgeDartDefines["FRIDGE_WECHAT_APP_ID"].orEmpty()
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.fenlengtech.fridge"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("projectIdentity") {
            storeFile = rootProject.file(projectSigning.getProperty("storeFile"))
            storePassword = projectSigning.getProperty("storePassword")
            keyAlias = projectSigning.getProperty("keyAlias")
            keyPassword = projectSigning.getProperty("keyPassword")
        }
    }
    buildTypes {
        debug { signingConfig = signingConfigs.getByName("projectIdentity") }

        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("projectIdentity")
        }
    }
}

flutter {
    source = "../.."
}
