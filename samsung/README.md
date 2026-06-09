# TempoRun — Wear OS (Android)

Módulo do app de relógio para **Wear OS** (Galaxy Watch e demais). Paridade de features com
o app de Apple Watch (`../apple`). Plano completo em [`../WEAR_OS_PLAN.md`](../WEAR_OS_PLAN.md);
decisões de arquitetura em [`DECISIONS.md`](DECISIONS.md).

## Stack

Kotlin · Jetpack **Compose for Wear OS** (Material estável) · **Health Services**
(`ExerciseClient`) · **Wearable Data Layer** · Gradle 8.14.3 / AGP 8.13.2 / Kotlin 2.0.21 ·
`applicationId` `com.temporun.run` (igual ao celular, p/ parear no Data Layer).

## Como buildar

Requer Android SDK (compileSdk 36) e JDK 17+. O `local.properties` (com `sdk.dir`) é gerado
localmente e **não** é versionado.

```bash
cd samsung
./gradlew :wear:assembleDebug      # gera o APK debug
./gradlew :wear:installDebug       # instala num relógio/emulador Wear OS pareado
```

No Android Studio: abrir a pasta `samsung/` como projeto.

## Estrutura

```
wear/src/main/java/com/temporun/run/wear/
├── presentation/   UI Compose (telas) + theme       ← Views/ (SwiftUI)
├── workout/        ExerciseManager, ViewModel,        ← Managers/WorkoutManager
│                   Service, LiveMetrics, zonas,
│                   splits, predições
├── connectivity/   DataLayerManager, WorkoutPayload   ← WatchSessionManager
├── training/       TrainingPlan + repositório         ← Models + TrainingPlanManager
└── network/        Supabase, fila offline, rede       ← Networking/
```

## Status (ver `../progresso.md`)

- **Fase 0 — Setup:** ✅ projeto Gradle, manifest, theme, esqueleto compilando.
- **Fase 1 — MVP corrida:** 🔄 estrutura pronta; falta captura completa de métricas,
  foreground service integrado, pager de 8 páginas, splits + haptic.
- **Fases 2–5:** ⏳ stubs documentados com `TODO(Fase X)`.

## Decisão de persistência

Corridas vão **sempre para a edge function `watch-workout-save`** (não há gravação direta na
tabela nem ponte para o JS do app). Detalhe e justificativa em [`DECISIONS.md`](DECISIONS.md).
`device = "wear_os"` (ou `"wear_os_standalone"`).
