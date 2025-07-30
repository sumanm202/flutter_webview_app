import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

// ✅ Define SDK versions
extra["compileSdkVersion"] = 36
extra["minSdkVersion"] = 24
extra["targetSdkVersion"] = 36

// ✅ Top-level buildscript for Firebase and Kotlin
buildscript{
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.3.1") // Android Gradle Plugin
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0") // Kotlin 2.1.0
        classpath("com.google.gms:google-services:4.3.15") // Firebase plugin
    }
}

// ✅ Global repositories and Java toolchain settings
allprojects {
    repositories {
        google()
        mavenCentral()
    }

//    // ✅ Force Java 17 compatibility for all Java compile tasks
//    tasks.withType<JavaCompile>().configureEach {
//        options.release.set(17) // or 11 if targeting Java 11
//    }
}

// ✅ Optional: Centralized custom build directory
val customBuildDir = rootProject.layout.buildDirectory.dir("../../build")

// ✅ Apply custom build directory to all modules
subprojects {
    afterEvaluate {
        layout.buildDirectory.set(customBuildDir.map { it.dir(name) })
    }
}

// ✅ Clean task to wipe the entire custom build dir
tasks.register<Delete>("clean") {
    delete(customBuildDir)
}
