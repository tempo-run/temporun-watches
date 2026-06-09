// Build raiz do módulo Wear OS. Configuração comum vive aqui; cada submódulo
// (por enquanto só :wear) tem seu próprio build.gradle.kts.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}
