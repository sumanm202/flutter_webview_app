import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

// ✅ Top-level buildscript for Firebase plugin
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // ✅ Firebase Google Services plugin (latest compatible)
        classpath("com.google.gms:google-services:4.3.15")
        classpath ("com.android.tools.build:gradle:8.0.2") // or latest
    }
}

// ✅ Apply global repositories for all modules
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Optional: Custom build directory (outside default .android/)
val customBuildDir = rootProject.layout.buildDirectory.dir("../../build")

// ⚠️ Kotlin DSL requires safe use of providers
subprojects {
    afterEvaluate {
        layout.buildDirectory.set(customBuildDir.map { it.dir(name) })
    }
}

// ✅ Clean task to remove custom build directory
tasks.register<Delete>("clean") {
    delete(customBuildDir)
}
