import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")

    // Add the Google services Gradle plugin
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

val admobProperties = Properties()
val admobPropertiesFile = rootProject.file("admob.properties")
if (admobPropertiesFile.exists()) {
    admobPropertiesFile.inputStream().use(admobProperties::load)
}

val admobAndroidTestAppId = "ca-app-pub-3940256099942544~3347511713"
val requestedGradleTasks = gradle.startParameter.taskNames.joinToString(" ").lowercase()
// Flavor definitions are configured up front, so only fail fast when a prod task
// is actually being built.
val isProdBuildRequested = requestedGradleTasks.contains("prod")

fun admobProperty(name: String, fallback: String): String {
    return admobProperties.getProperty(name) ?: System.getenv(name) ?: fallback
}

fun prodAdmobProperty(name: String): String {
    val value = admobProperties.getProperty(name) ?: System.getenv(name)
    if (value.isNullOrBlank()) {
        if (!isProdBuildRequested) {
            return admobAndroidTestAppId
        }
        throw GradleException("Missing required AdMob property: $name")
    }
    if (value == admobAndroidTestAppId && isProdBuildRequested) {
        throw GradleException("AdMob property $name must not use the Google test App ID in prod")
    }
    return value
}

dependencies {
  // Import the Firebase BoM
  implementation(platform("com.google.firebase:firebase-bom:34.10.0"))

  // TODO: Add the dependencies for Firebase products you want to use
  // When using the BoM, don't specify versions in Firebase dependencies
  implementation("com.google.firebase:firebase-analytics")

  // Add the dependencies for any other desired Firebase products
  // https://firebase.google.com/docs/android/setup#available-libraries
}

android {
    namespace = "dev.asobo.boatface"
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
        applicationId = "dev.asobo.boatface"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    flavorDimensions += "environment"
    productFlavors {
        create("stg") {
            dimension = "environment"
            applicationId = "dev.asobo.boatface.stg"
            manifestPlaceholders["appName"] = "BoatFace Stg"
            manifestPlaceholders["admobApplicationId"] = admobAndroidTestAppId
        }
        create("prod") {
            dimension = "environment"
            applicationId = "dev.asobo.boatface"
            manifestPlaceholders["appName"] = "BoatFace"
            manifestPlaceholders["admobApplicationId"] = prodAdmobProperty(
                "ADMOB_ANDROID_APP_ID_PROD",
            )
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
