plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.jungwuk.boc"
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jungwuk.boc"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        multiDexEnabled = true
        minSdk = flutter.minSdkVersion
        targetSdk = maxOf(flutter.targetSdkVersion, 36)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

val generatedPluginRegistrant = layout.projectDirectory.file(
    "src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java",
)

val scrubReleaseGeneratedPluginRegistrant =
    tasks.register("scrubReleaseGeneratedPluginRegistrant") {
        inputs.file(generatedPluginRegistrant)
        outputs.file(generatedPluginRegistrant)

        doLast {
            val file = generatedPluginRegistrant.asFile
            if (!file.exists()) {
                return@doLast
            }

            val integrationTestRegistration = """
    try {
      flutterEngine.getPlugins().add(new dev.flutter.plugins.integration_test.IntegrationTestPlugin());
    } catch (Exception e) {
      Log.e(TAG, "Error registering plugin integration_test, dev.flutter.plugins.integration_test.IntegrationTestPlugin", e);
    }
"""
                .trimIndent()

            val source = file.readText()
            if (!source.contains(integrationTestRegistration)) {
                return@doLast
            }

            file.writeText(source.replace("$integrationTestRegistration\n", ""))
        }
    }

tasks.matching { it.name.startsWith("compileRelease") }.configureEach {
    dependsOn(scrubReleaseGeneratedPluginRegistrant)
}
