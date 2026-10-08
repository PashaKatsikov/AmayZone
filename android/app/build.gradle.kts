import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.amayzone.world"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.amayzone.world"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// --- Rust slot math ---------------------------------------------------------
// The shared library is rebuilt through cargo-ndk whenever the crate changes.

val rustCrate = rootProject.projectDir.parentFile.resolve("rust/slot_core")
val jniLibsDir = layout.projectDirectory.dir("src/main/jniLibs").asFile

val buildSlotCore by tasks.registering(Exec::class) {
    group = "build"
    description = "Compiles rust/slot_core for every supported Android ABI"
    workingDir = rustCrate

    inputs.files(
        rustCrate.resolve("Cargo.toml"),
        rustCrate.resolve("build.rs"),
    )
    inputs.dir(rustCrate.resolve("src"))
    inputs.dir(rustCrate.resolve("math"))
    outputs.dir(jniLibsDir)

    commandLine(
        "cargo", "ndk",
        "-t", "arm64-v8a",
        "-t", "armeabi-v7a",
        "-t", "x86_64",
        "-P", "24",
        "-o", jniLibsDir.absolutePath,
        "build", "--release",
    )

    doFirst {
        val ndk = android.sdkDirectory.resolve("ndk/${android.ndkVersion}")
        environment("ANDROID_NDK_HOME", ndk.absolutePath)
    }
}

tasks.matching { it.name == "preBuild" }.configureEach {
    dependsOn(buildSlotCore)
}
