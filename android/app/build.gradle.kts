plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") // ✅ Firebase plugin
    id("dev.flutter.flutter-gradle-plugin") // ✅ Flutter plugin (must be last)
}

android {
    namespace = "com.example.flutter_webview_app"
    compileSdk = rootProject.extra["compileSdkVersion"] as Int

    ndkVersion = "27.0.12077973" // ✅ Only if using native C++/FFmpeg

    defaultConfig {
        applicationId = "com.example.flutter_webview_app"
        minSdk = rootProject.extra["minSdkVersion"] as Int
        targetSdk = rootProject.extra["targetSdkVersion"] as Int
        versionCode = 1
        versionName = "1.0"

        multiDexEnabled = true // ✅ Required for Firebase and large apps
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildFeatures {
        viewBinding = true
    }
}

dependencies {
    // ✅ Java 8+ desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // ✅ Firebase
    implementation("com.google.firebase:firebase-messaging:25.0.0")
    implementation("com.google.firebase:firebase-analytics:21.6.1")
    // implementation("com.google.firebase:firebase-crashlytics") // Optional
}

flutter {
    source = "../.."
}
