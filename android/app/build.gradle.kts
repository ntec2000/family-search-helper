plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.peterchoi.familysearchhelper"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    defaultConfig {
        applicationId = "com.peterchoi.familysearchhelper"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            ndk { debugSymbolLevel = "none" }
        }
    }
    buildFeatures { buildConfig = false }
}

dependencies {
    // 한자(중국어) 인식 모델을 APK 에 직접 번들 — 완전 오프라인·온디바이스.
    // google_mlkit_text_recognition 플러그인은 이 모듈을 compileOnly 로만
    // 선언하므로(=APK 미포함), 직접 implementation 으로 추가하지 않으면
    // 한자 인식 호출 시 네이티브 코드 부재로 강제 종료된다. (v1.0.6 핵심 수정)
    // 16.0.1 = 16KB 페이지 정렬 네이티브 라이브러리.
    implementation("com.google.mlkit:text-recognition:16.0.1")
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
}

flutter { source = "../.." }
