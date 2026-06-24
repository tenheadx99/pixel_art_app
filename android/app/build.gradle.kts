import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

// Load signing credentials from android/key.properties (git-ignored). Absent on
// CI / fresh checkouts — in that case the release build falls back to debug
// signing so the build still completes (do not distribute such an artifact).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.europosit.pixel_art_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.tenhead.pixelyart"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Use the real upload key when key.properties is present; otherwise
            // fall back to debug signing so the build still completes locally/CI.
            signingConfig = if (hasReleaseSigning) {
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

    flavorDimensions += "app"
    productFlavors {
        // Original neon/synthwave pixel-art app.
        create("original") {
            dimension = "app"
            applicationId = "com.tenhead.pixelyart"
            resValue("string", "app_name", "PixelPause")
        }
        // "Divine Pixels" — Indian god & goddess devotional flavor.
        create("devotional") {
            dimension = "app"
            applicationId = "com.tenhead.divinepixels"
            resValue("string", "app_name", "Divine Pixels")
        }
        // "Anime Pixels" — anime/manga fan flavor.
        create("anime") {
            dimension = "app"
            applicationId = "com.tenhead.animepixels"
            resValue("string", "app_name", "Anime Pixels")
        }
        // "PixelCalm" — mindfulness / stress-relief flavor.
        create("pixelcalm") {
            dimension = "app"
            applicationId = "com.tenhead.pixelcalm"
            resValue("string", "app_name", "PixelCalm")
        }
        // "Gem Art" — diamond-painting flavor (gem-rendered cells).
        create("diamond") {
            dimension = "app"
            applicationId = "com.tenhead.gemart"
            resValue("string", "app_name", "Gem Art")
        }
    }

    lint {
        checkReleaseBuilds = true
        abortOnError = true
        // Translations are intentionally single-locale for now.
        disable += "MissingTranslation"
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
