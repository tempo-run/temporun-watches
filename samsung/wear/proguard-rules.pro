# Regras ProGuard/R8 do módulo Wear OS.
# Por enquanto release não usa minify (ver build.gradle.kts). Quando ligar,
# manter os modelos serializáveis do kotlinx.serialization.
-keepattributes *Annotation*, InnerClasses
-keep,includedescriptorclasses class com.temporun.run.wear.**$$serializer { *; }
-keepclassmembers class com.temporun.run.wear.** {
    *** Companion;
}
-keepclasseswithmembers class com.temporun.run.wear.** {
    kotlinx.serialization.KSerializer serializer(...);
}
