plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.firebase-perf")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.goaegent.securityexperts"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

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
        applicationId = "com.goaegent.securityexperts"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
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

    // Flutter remaps the Gradle `buildDir` (see android/build.gradle.kts) so the
    // google-services plugin generates `values.xml` (with google_app_id, etc.)
    // under <project>/build/app/generated/res/google-services/<variant>/values/
    // but AGP's mergeResources doesn't auto-discover it under the remapped path
    // on this Flutter / AGP / google-services combination. Without it,
    // FirebaseInitProvider can't find the default options at runtime and any
    // call to FirebaseAuth.getInstance() throws "Default FirebaseApp is not
    // initialized". Explicitly register the directory as a per-variant res
    // srcset so the merge picks it up.
    sourceSets {
        getByName("debug") {
            res.srcDirs(rootProject.layout.buildDirectory.dir("app/generated/res/google-services/debug"))
        }
        getByName("release") {
            res.srcDirs(rootProject.layout.buildDirectory.dir("app/generated/res/google-services/release"))
        }
    }
}

// AGP can't infer the implicit producer→consumer dependency between
// processXxxGoogleServices and every task that scans the res source
// paths (mergeResources, generateResources, mapSourceSetPaths,
// packageResources, extractDeepLinks, lint*, etc.) once we add the
// generated directory as a manual srcset above. Declare the dependency
// on every variant-scoped consumer that runs after source collection.
afterEvaluate {
    listOf("Debug", "Release").forEach { variant ->
        val producer = tasks.findByName("process${variant}GoogleServices") ?: return@forEach
        tasks.matching { task ->
            val n = task.name
            n != producer.name && n.contains(variant) && (
                n.startsWith("merge") ||
                    n.startsWith("generate") ||
                    n.startsWith("map") && n.contains("SourceSet") ||
                    n.startsWith("package") && n.contains("Resources") ||
                    n.startsWith("extractDeepLinks") ||
                    n.startsWith("lint") ||
                    n.startsWith("process") && n.endsWith("Manifest")
                )
        }.configureEach {
            dependsOn(producer)
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Required by GoAegentMessagingService (native FCM handler that dispatches
    // CallKit broadcasts directly from the main process for `incoming_call`).
    implementation("com.google.firebase:firebase-messaging:25.0.1")
    // Used by RejectCallWorker to call the `api{action:rejectCall}` Cloud
    // Function from the cold-start decline path WITHOUT needing the Flutter
    // engine — the firebase_messaging Flutter plugin only pulls in
    // firebase-messaging transitively, so we declare functions / auth /
    // workmanager explicitly here.
    implementation("com.google.firebase:firebase-functions:21.1.0")
    implementation("com.google.firebase:firebase-auth:23.1.0")
    implementation("androidx.work:work-runtime-ktx:2.9.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.9.0")
}
