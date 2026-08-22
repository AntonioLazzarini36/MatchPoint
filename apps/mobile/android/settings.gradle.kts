pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    // Lee `app/google-services.json` y genera los recursos que el SDK de
    // Firebase busca en tiempo de ejecución. Sin este plugin la app compila
    // igual y luego falla al arrancar diciendo que no encuentra la
    // configuración, que es de los errores menos evidentes de Firebase.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
