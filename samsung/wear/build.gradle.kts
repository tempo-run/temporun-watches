import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "com.temporun.run.wear"
    compileSdk = 35

    defaultConfig {
        // applicationId IGUAL ao app do celular — obrigatório para o Wearable Data
        // Layer reconhecer os dois como apps companheiros. Ver samsung/DECISIONS.md (D3).
        applicationId = "com.temporun.run"
        minSdk = 30          // Wear OS 3 — mínimo para Health Services
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

dependencies {
    implementation(libs.core.ktx)
    implementation(libs.activity.compose)

    // Compose (BOM gerencia versões)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.tooling.preview)
    debugImplementation(libs.compose.ui.tooling)

    // Wear Compose
    implementation(libs.wear.compose.material)
    implementation(libs.wear.compose.foundation)
    implementation(libs.wear.compose.navigation)
    implementation(libs.wear.ongoing)

    // Lifecycle / ViewModel
    implementation(libs.lifecycle.viewmodel.compose)
    implementation(libs.lifecycle.runtime.compose)

    // Health Services — sessão de exercício e sensores
    implementation(libs.health.services.client)
    implementation(libs.concurrent.futures.ktx)
    implementation(libs.guava)

    // Wearable Data Layer — comunicação com o celular
    implementation(libs.play.services.wearable)

    // Serialização / coroutines
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.android)

    // Testes unitários (JVM — rodam sem relógio)
    testImplementation(libs.junit)
}
