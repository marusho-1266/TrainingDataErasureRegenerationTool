import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.trainingdataerasure.regenerationtool"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.trainingdataerasure.regenerationtool"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    }

    fun envOrProp(envKey: String, propKey: String): String? =
        System.getenv(envKey)?.takeIf { it.isNotEmpty() }
            ?: (keystoreProperties[propKey] as String?)?.takeIf { it.isNotEmpty() }

    val storePath = envOrProp("ANDROID_KEYSTORE_PATH", "storeFile")
    val storePwd = envOrProp("ANDROID_KEYSTORE_PASSWORD", "storePassword")
    val alias = envOrProp("ANDROID_KEY_ALIAS", "keyAlias")
    val keyPwd = envOrProp("ANDROID_KEY_PASSWORD", "keyPassword")
    val releaseKeystoreConfigured =
        storePath != null && storePwd != null && alias != null && keyPwd != null

    signingConfigs {
        create("release") {
            if (releaseKeystoreConfigured) {
                storeFile = file(storePath!!)
                storePassword = storePwd!!
                keyAlias = alias!!
                keyPassword = keyPwd!!
            }
        }
    }

    buildTypes {
        release {
            // Use upload keystore when key.properties or env vars are set; else debug for local runs.
            signingConfig = if (releaseKeystoreConfigured) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
