import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

// ✅ Define SDK versions for use in app module
extra.set("compileSdkVersion", 36)
extra.set("minSdkVersion", 24)
extra.set("targetSdkVersion", 36)

// ✅ Top-level buildscript for Firebase plugin and Kotlin
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.3.15")
        classpath("com.android.tools.build:gradle:8.3.0") // ✅ Match AGP to Kotlin 2.1.0
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
    }
}

// ✅ Apply global repositories for all modules
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Optional: Custom build directory
val customBuildDir = rootProject.layout.buildDirectory.dir("../../build")

// ✅ Use custom build directory safely in subprojects
subprojects {
    afterEvaluate {
        layout.buildDirectory.set(customBuildDir.map { it.dir(name) })
    }
}

// ✅ Clean task to remove custom build directory
tasks.register<Delete>("clean") {
    delete(customBuildDir)
}
