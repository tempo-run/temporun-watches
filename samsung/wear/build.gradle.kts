import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.io.FileInputStream
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

// Assinatura de release: as credenciais vêm de samsung/keystore.properties, que
// fica FORA do git (ver .gitignore). Use a MESMA upload key do app de telefone —
// wear e celular compartilham o applicationId com.temporun.run, logo são o MESMO
// app na Play e precisam ser assinados com a mesma chave. Se o arquivo não
// existir (CI, máquina sem a keystore), o release sai sem assinar e o build NÃO
// quebra — útil para `:wear:checkNoHealthConnect`, testes, etc.
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
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
        // Mesmo applicationId do celular => MESMO app na Play. O versionCode do
        // wear precisa ser ÚNICO e maior que o último publicado. O celular usa a
        // faixa 2026xxxx (próximo build dele = 20260641); o wear vai logo acima.
        versionCode = 20260642
        versionName = "1.0.41"
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Assina só quando há keystore.properties (build de release local).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                null
            }
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

    // Complications + Tiles (Fase 4 — glanceability)
    implementation(libs.watchface.complications.data.source.ktx)
    implementation(libs.wear.tiles)
    implementation(libs.wear.protolayout)
    implementation(libs.wear.protolayout.material)

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
    implementation(libs.kotlinx.coroutines.play.services) // await() em Tasks do Play Services

    // Testes unitários (JVM — rodam sem relógio)
    testImplementation(libs.junit)
}

// ── Trava de regressão: proíbe Health Connect no :wear ───────────────────────
// O relógio usa Health Services (androidx.health:health-services-client). NUNCA
// adicionar androidx.health.connect:connect-client — ele declara ~40 permissões
// android.permission.health.* no manifesto e reprova na Play por excesso de
// permissões. Esta task quebra o build se o Health Connect aparecer no grafo
// (direto ou transitivo).
tasks.register("checkNoHealthConnect") {
    group = "verification"
    description = "Falha o build se androidx.health.connect entrar no grafo do :wear."
    doLast {
        val offenders = sortedSetOf<String>()
        configurations
            .filter { it.isCanBeResolved && it.name.endsWith("RuntimeClasspath") }
            .forEach { config ->
                runCatching {
                    config.incoming.resolutionResult.allComponents.forEach { comp ->
                        val mv = comp.moduleVersion
                        if (mv != null && mv.group == "androidx.health.connect") {
                            offenders.add("${mv.group}:${mv.name}:${mv.version}")
                        }
                    }
                }
            }
        if (offenders.isNotEmpty()) {
            throw GradleException(
                "❌ Health Connect proibido no modulo :wear -> $offenders\n" +
                "Use SOMENTE androidx.health:health-services-client (Health Services).\n" +
                "O Health Connect injeta ~40 permissoes android.permission.health.* no " +
                "manifesto e reprova na Google Play por excesso de permissoes."
            )
        }
    }
}
// Roda em todo build (preBuild) e em ./gradlew check
tasks.matching { it.name == "preBuild" }.configureEach { dependsOn("checkNoHealthConnect") }
tasks.matching { it.name == "check" }.configureEach { dependsOn("checkNoHealthConnect") }
