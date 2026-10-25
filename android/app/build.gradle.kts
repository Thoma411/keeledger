plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.thoma4.keeledger"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        create("release") {
            val keystoreFile = file("upload-keystore.jks")
            val envStorePassword = System.getenv("SIGNING_STORE_PASSWORD")
            val envKeyAlias = System.getenv("SIGNING_KEY_ALIAS")
            val envKeyPassword = System.getenv("SIGNING_KEY_PASSWORD")
            val isReleaseTask = gradle.startParameter.taskNames.any {
                it.contains("release", ignoreCase = true)
            }
            if (isReleaseTask) {
                val missing = mutableListOf<String>()
                if (envStorePassword.isNullOrEmpty()) missing.add("SIGNING_STORE_PASSWORD")
                if (envKeyAlias.isNullOrEmpty()) missing.add("SIGNING_KEY_ALIAS")
                if (envKeyPassword.isNullOrEmpty()) missing.add("SIGNING_KEY_PASSWORD")
                if (!keystoreFile.exists()) missing.add("android/app/upload-keystore.jks")
                if (missing.isNotEmpty()) {
                    throw GradleException(
                        "Missing release signing material: ${missing.joinToString(", ")}. " +
                            "Provide them via environment variables and place the keystore " +
                            "at android/app/upload-keystore.jks (the file is not tracked)."
                    )
                }
                storeFile = keystoreFile
                storePassword = envStorePassword
                keyAlias = envKeyAlias
                keyPassword = envKeyPassword
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true // 满足ota_update的AAR静态依赖检查
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.thoma4.keeledger"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
