group = "com.jk.ocr.flutter"
version = "0.1.0"

buildscript {
    val kotlinVersion = "2.4.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.1.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// SDK native (com.jk.ocr:ocr-core / ocr-camera / ocr-scanner) nằm trong repo Maven cục bộ `maven/`
// của package này (sinh bởi tool/sync_native.sh). Repo phải hiển thị cho cả app host, vì app
// phân giải các dependency bắc cầu của thư viện này.
val jkOcrMavenDir = file("maven")
rootProject.allprojects {
    repositories {
        maven { url = uri(jkOcrMavenDir) }
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.jk.ocr.flutter"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("com.jk.ocr:ocr-scanner:0.1.0")
}
