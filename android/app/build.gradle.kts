plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") // ✅ Firebase plugin
    id("dev.flutter.flutter-gradle-plugin") // ✅ Flutter plugin (must be last)
}

android {
    namespace = "com.example.flutter_webview_app"
    compileSdk = rootProject.extra["compileSdkVersion"] as Int
    ndkVersion = "27.0.12077973" // ✅ Only if you're using native C++ code

    defaultConfig {
        applicationId = "com.example.flutter_webview_app"
        minSdk = rootProject.extra["minSdkVersion"] as Int
        targetSdk = rootProject.extra["targetSdkVersion"] as Int
        versionCode = 1
        versionName = "1.0"
        multiDexEnabled = true
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
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
        freeCompilerArgs += listOf("-Xjvm-default=all") // Optional
    }

    buildFeatures {
        viewBinding = true
    }
}

dependencies {
    // ✅ Enable Java 8+ APIs (e.g. java.time)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // ✅ Firebase core services
    implementation("com.google.firebase:firebase-messaging:25.0.0")
    implementation("com.google.firebase:firebase-analytics:23.0.0")

    // Optional: Firebase extensions
    // implementation("com.google.firebase:firebase-crashlytics")
    // implementation("com.google.firebase:firebase-auth")
    // implementation("com.google.firebase:firebase-firestore")
}

flutter {
    source = "../.."
}
