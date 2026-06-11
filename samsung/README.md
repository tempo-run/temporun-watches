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
- **Fase 1 — MVP corrida:** ✅ captura completa, zonas de FC, splits + haptic, foreground service
  com Ongoing Activity, pager de 7 páginas, resumo, permissões runtime.
- **Fase 2 — Data Layer:** ✅ corrida (entrega garantida) + live update; plugin do celular entregue.
- **Fase 3 — Plano + alerta de pace:** ✅ plano no relógio, abas Hoje/Semana/Status, haptic por zona.
- **Fase 5 — Standalone + fila offline:** ✅ Supabase direto, fila persistida, sync ao reconectar.
- **Fase 4 — Complications + Tiles:** ✅ data source (km/streak/próximo treino) + tile ProtoLayout.
- **46 testes unitários** (JVM). ⚠️ Validação em Galaxy Watch físico pendente em todas as fases.
- **Backend:** auditoria do contrato em [`../CONTRACT_AUDIT.md`](../CONTRACT_AUDIT.md);
  migração `wear_os` em [`supabase/wear_migration.sql`](supabase/wear_migration.sql).

## Testes

```bash
./gradlew :wear:testDebugUnitTest   # roda na JVM, não precisa de relógio
```

## Decisão de persistência

Corridas vão **sempre para a edge function `watch-workout-save`** (não há gravação direta na
tabela nem ponte para o JS do app). Detalhe e justificativa em [`DECISIONS.md`](DECISIONS.md).
`device = "wear_os"` (ou `"wear_os_standalone"`).
