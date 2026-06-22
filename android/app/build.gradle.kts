plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.europosit.pixel_art_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        create("release") {
            storeFile = file("/home/rameshx99/pixel_art_app/universal_signing_key.jks")
            storePassword = "tenhead"
            keyAlias = "tenhead"
            keyPassword = "tenhead"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
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
            // FIXED: signingConfig accesses the config created above
            signingConfig = signingConfigs.getByName("release")
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
        checkReleaseBuilds = false
        abortOnError = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
