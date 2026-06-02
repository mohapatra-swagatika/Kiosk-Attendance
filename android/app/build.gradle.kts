plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.attendance_kiosk_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.attendance_kiosk_app"
        // ML Kit Face Detection + Firebase require API 24+; TFLite + camera plugins work above this.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // TFLite models must NOT be gzip-compressed inside the APK — otherwise the
    // Interpreter cannot mmap the asset on Android and inference silently fails
    // even though iOS (which ships assets uncompressed) works fine.
    androidResources {
        noCompress += listOf("tflite", "lite")
    }

    // tflite_flutter ships a precompiled JNI; keep it as a real .so on disk so
    // System.loadLibrary finds it on devices that don't support extractNativeLibs=false.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    // GpuDelegate (tensorflow-lite-gpu) references GpuDelegateFactory$Options from
    // this artifact; without it R8 fails on release builds (tflite_flutter 0.11.x).
    implementation("org.tensorflow:tensorflow-lite-gpu-api:2.11.0")
}

flutter {
    source = "../.."
}
