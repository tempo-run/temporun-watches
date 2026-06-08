# Plano de Implementação — TempoRun Wear OS (Samsung / Android)

> Documento de planejamento. **Ainda não escreve o app** — mapeia o app de Apple Watch
> existente e propõe a abordagem para o módulo Wear OS com paridade de features.
> Pasta de destino do código: `samsung/`.

---

## 0. Resumo executivo

O app de **Apple Watch** (`apple/TempoRunWatch`) já está completo nas Fases 0–5: grava a
corrida no relógio com `HKWorkoutSession`/`HKLiveWorkoutBuilder`, captura ~40 métricas
(corrida, biomecânica, cardio, energia, altitude, splits, predições), sincroniza com o
iPhone via `WatchConnectivity`, funciona **standalone** (grava direto no Supabase via uma
edge function `watch-workout-save`), tem **complications** + **Smart Stack widget**, e
integra com o **plano de treino** (treino do dia, alertas de pace por zona).

O objetivo do Wear OS é **paridade de features**, reaproveitando **todo o backend já
construído** (mesma tabela `corridas`, mesma edge function, mesmo schema de plano).
A camada de relógio é reescrita em **Kotlin + Compose for Wear OS + Health Services**.

**Inversão arquitetural importante (ler antes de tudo):** no Apple Watch o caminho de
menor esforço é "gravar no HealthKit e deixar o iPhone importar automaticamente"
(Caminho A). **Esse caminho não existe de forma equivalente no Wear OS** — não há um
"Health Connect compartilhado" que o app do celular leia sozinho do relógio. No Wear OS o
caminho primário é o **Data Layer** (relógio → celular) ou o **standalone** (relógio →
Supabase direto). Detalhe na seção 6.

---

## 1. Mapa do app de Apple Watch existente

### 1.1. Stack e estrutura

| Camada | Apple Watch |
|--------|-------------|
| Linguagem/UI | Swift 5.9 + SwiftUI |
| Sessão de treino | `HKWorkoutSession` + `HKLiveWorkoutBuilder` (HealthKit) |
| GPS / rota | `CLLocationManager` + `HKWorkoutRouteBuilder` |
| Comunicação c/ celular | `WatchConnectivity` (`WCSession`) |
| Dados compartilhados local | App Group `group.com.temporun.run` (UserDefaults) |
| Standalone | `URLSession` → edge function Supabase |
| Complications / glance | `ClockKit` + WidgetKit (Smart Stack) |
| Build | XcodeGen (`project.yml`) + Codemagic (`mac_mini_m2`) |
| Deploy target | watchOS 10.0 · bundle `com.temporun.run.watchkitapp` |

Estrutura de arquivos (Swift):

```
apple/TempoRunWatch/Sources/TempoRunWatch/
├── TempoRunWatchApp.swift          # @main, injeta managers
├── Extensions.swift                # formatadores pace/duração/distância
├── Managers/
│   ├── WorkoutManager.swift        # núcleo: sessão, métricas, splits, zonas, save
│   ├── WatchSessionManager.swift   # WCSession (envia ao iPhone) + payloads Codable
│   └── TrainingPlanManager.swift   # recebe plano, alertas de pace por zona
├── Models/
│   └── TrainingPlan.swift          # WorkoutType, DailyWorkout, TrainingWeek, TrainingPlan
├── Networking/
│   ├── SupabaseClient.swift        # URLSession → edge function + refresh token
│   ├── OfflineQueue.swift          # fila persistida, retry com backoff, max 5
│   └── NetworkMonitor.swift        # NWPathMonitor → sync automático
├── Views/
│   ├── ContentView.swift           # navegação por estado (idle/running/ended)
│   ├── StartView.swift             # iniciar corrida livre
│   ├── LiveMetricsView.swift       # 8 páginas de métricas ao vivo (TabView)
│   ├── SummaryView.swift           # resumo pós-corrida por seção
│   ├── TodayWorkoutView.swift      # treino do dia + WeekPlanView
│   ├── PaceAlertOverlay.swift      # overlay de alerta de pace (4s)
│   └── StandaloneStatusView.swift  # status de rede/credenciais/fila
└── Complications/
    ├── ComplicationProvider.swift  # CLKComplicationDataSource (10 famílias)
    └── WidgetBundle.swift          # Smart Stack widget (rect/circular/corner/inline)

apple/  (lado iPhone — adicionado ao temporun-app)
├── PhoneSessionManager.swift       # recebe corrida do Watch → schema corridas
├── PlanSyncToWatch.swift           # envia plano ativo ao Watch
├── CredentialSyncToWatch.swift     # envia tokens Supabase ao Watch (standalone)
└── ComplicationSyncToWatch.swift   # envia dados de complicação

apple/supabase/
├── functions/watch-workout-save/index.ts   # XP + streak + recordes atômicos
├── watch_migration.sql                      # colunas novas em corridas + dedup
└── watch_triggers.sql
```

### 1.2. Métricas capturadas (alvo de paridade)

**Corrida:** distância (km), pace atual/médio/melhor (seg/km), velocidade (m/s), passos,
cadência (spm).
**Biomecânica (Running Dynamics):** comprimento de passada (m), potência (W), tempo de
contato com o solo (ms), oscilação vertical (cm), vertical ratio (%), esforço físico (METs).
**Cardio & saúde:** FC atual/média/mín/máx, FC de repouso, HRV-SDNN (ms), SpO₂ (%),
frequência respiratória (r/min), VO₂ máx, zona de FC atual (Z1–Z5) e tempo por zona.
**Energia:** kcal ativas, basais e total.
**Altitude/GPS:** altitude atual/máx/mín, ganho/perda de elevação, lances subidos, rota GPS.
**Splits & predições:** splits por km (pace, FC média, ganho de elevação), haptic por split,
preditor de prova 5k/10k/meia/maratona (Daniels & Gilbert).

### 1.3. Contrato de dados (o que entregar ao backend)

A edge function `watch-workout-save` (POST `/functions/v1/watch-workout-save`, header
`Authorization: Bearer <accessToken>` + `apikey`) recebe um JSON com estes campos
(nomes **exatos** — o cliente Wear OS deve replicar):

```
distancia_km, duracao_seg, pace_medio(seg/km), pace_melhor, velocidade_media,
step_count, cadencia, stride_length, running_power, ground_contact, vertical_osc,
vertical_ratio, physical_effort, bpm_medio, fc_min, fc_max, fc_repouso, hrv_sdnn,
spo2, frequencia_resp, vo2_estimado, tempo_zona1..5, calorias_ativas, calorias_basais,
calorias_total, ganho_elevacao, perda_elevacao, altitude_max, altitude_min,
splits[{km,duracao,pace,fc_media,ganho_elevacao}], data_inicio(ISO), data_fim(ISO),
source, (opcional) plano_id, plano_semana, treino_tipo
```

Resposta: `{ corrida_id, xp_ganho, streak_atual, novos_recordes[], is_duplicate }`.
A função faz **deduplicação** (±30s de `data_inicio`), calcula **XP** (`km*45 + min*2`),
atualiza **streak** (semanas únicas com corrida) e **recordes pessoais** (12 distâncias,
interpolação proporcional). **Nada disso precisa ser reescrito** — o Wear OS só precisa
enviar o payload no formato certo.

> ⚠️ Pequeno ajuste de backend necessário: o índice único de dedup
> `corridas_watch_dedup_idx` e a função `merge_watch_corrida` hoje cobrem só
> `device IN ('apple_watch','apple_watch_standalone')`. Estender para incluir
> `'wear_os'` e `'wear_os_standalone'` (ver seção 9).

---

## 2. Realidade técnica do Wear OS

Wear OS é Android. **Não há reuso de Swift/SwiftUI nem de React/Capacitor** dentro do
relógio — é um app nativo Android separado, com sua própria UI (Compose) e seu próprio
acesso a sensores (Health Services). Diferenças estruturais que mudam o desenho:

1. **Sem App Group.** Relógio e celular são dispositivos distintos com armazenamentos
   isolados. Toda troca de credenciais/plano/dados vai pelo **Wearable Data Layer**;
   cache local fica em **DataStore/Room** em cada lado.
2. **Sem import automático via "Health".** O análogo do HealthKit (Health Connect) é
   primariamente do **celular** e não sincroniza sozinho a partir do relógio. O caminho
   primário passa a ser Data Layer ou standalone (seção 6).
3. **Foreground Service obrigatório.** Para a corrida continuar gravando com a tela
   apagada/no pulso, o Android exige um **foreground service** + **Ongoing Activity**.
   No watchOS o `HKWorkoutSession` já cuida disso; no Wear OS é responsabilidade nossa.
4. **Lado celular é Capacitor.** O `temporun-app` Android é React Native + Capacitor. Para
   receber dados do relógio (equivalente ao `PhoneSessionManager`), precisamos de um
   **Capacitor plugin nativo (Kotlin)** com um `WearableListenerService` que faz a ponte
   para o JS — ou que grava direto no Supabase. Decisão na seção 6.

---

## 3. Stack recomendada

| Função | Apple Watch | → Wear OS (recomendado) |
|--------|-------------|--------------------------|
| Linguagem | Swift 5.9 | **Kotlin** (latest stable) |
| UI | SwiftUI | **Jetpack Compose for Wear OS** (`androidx.wear.compose` Material 3) |
| Sessão de treino | HKWorkoutSession + HKLiveWorkoutBuilder | **Health Services `ExerciseClient`** (`androidx.health.services.client`) |
| GPS / rota | CLLocationManager + HKWorkoutRouteBuilder | `FusedLocationProviderClient` (location já vem no `ExerciseUpdate`; rota acumulada manualmente) |
| Métricas passivas (FC repouso, VO₂, HRV, SpO₂) | HKSampleQuery | **Health Connect** no celular (histórico) ou `PassiveMonitoringClient` |
| Comunicação c/ celular | WatchConnectivity | **Wearable Data Layer** (`play-services-wearable`: `MessageClient`, `DataClient`, `CapabilityClient`, `ChannelClient`) |
| Cache local | App Group UserDefaults | **DataStore (Preferences)** + **Room** (fila offline) |
| Standalone HTTP | URLSession | **Ktor Client** (ou Retrofit/OkHttp) → mesma edge function |
| Fila offline + retry | OfflineQueue (custom) | **Room + WorkManager** (backoff exponencial) |
| Conectividade | NWPathMonitor | `ConnectivityManager.NetworkCallback` |
| Complication | ClockKit | **Wear OS Complications** (`androidx.wear.watchface.complications.datasource`) |
| Smart Stack widget | WidgetKit | **Tiles** (`androidx.wear.tiles` + Tiles Material) |
| Notificação de treino ativo | (implícito no HK) | **Ongoing Activity API** (`androidx.wear.ongoing`) |
| Haptics | WKInterfaceDevice.play | `Vibrator` / `VibrationEffect` |
| Treino guiado/intervalos | WorkoutKit | `ExerciseGoal` / milestones do Health Services + alertas custom |
| Build | XcodeGen + Codemagic | **Gradle (KTS)** + Android Studio; CI Codemagic Android ou GitHub Actions |
| Distribuição | TestFlight | **Play Console** — internal testing track |

**Versões-alvo:** `minSdk` 30 (Wear OS 3) / 33 recomendado, `targetSdk` mais recente.
Health Services exige Wear OS 3+. A maioria dos Galaxy Watch 4+ (que rodam Wear OS) é
compatível.

**Bibliotecas-chave (Gradle):**
```
androidx.health:health-services-client
androidx.wear.compose:compose-material3
androidx.wear.compose:compose-foundation
androidx.wear.compose:compose-navigation
com.google.android.gms:play-services-wearable
androidx.wear.tiles:tiles + tiles-material
androidx.wear.watchface:watchface-complications-data-source-ktx
androidx.wear:wear-ongoing
androidx.health.connect:connect-client            # leitura de métricas passivas no celular
io.ktor:ktor-client-android + ktor-client-content-negotiation
androidx.room:room-runtime                          # fila offline
androidx.work:work-runtime-ktx                      # sync/retry
androidx.datastore:datastore-preferences
```

---

## 4. Estrutura de pastas proposta (`samsung/`)

Projeto Gradle multi-módulo. `applicationId = "com.temporun.run"` (mesmo do app Android),
para entrega/instalação do app de relógio acoplada quando possível.

```
samsung/
├── settings.gradle.kts
├── build.gradle.kts
├── gradle/libs.versions.toml          # version catalog
├── wear/                              # módulo do app Wear OS
│   ├── build.gradle.kts
│   └── src/main/
│       ├── AndroidManifest.xml        # foreground service, permissões, Tiles, complications
│       └── java/run/temporun/wear/
│           ├── TempoRunWearApp.kt              # Application + DI (Hilt opcional)
│           ├── MainActivity.kt                 # host do Compose
│           ├── presentation/                   # ↔ Views/ (SwiftUI)
│           │   ├── TempoRunNavHost.kt          # ↔ ContentView (navegação por estado)
│           │   ├── start/StartScreen.kt        # ↔ StartView
│           │   ├── live/LiveMetricsPager.kt    # ↔ LiveMetricsView (8 páginas, HorizontalPager)
│           │   ├── summary/SummaryScreen.kt    # ↔ SummaryView
│           │   ├── plan/TodayWorkoutScreen.kt  # ↔ TodayWorkoutView
│           │   ├── plan/WeekPlanScreen.kt      # ↔ WeekPlanView
│           │   ├── plan/PaceAlertOverlay.kt    # ↔ PaceAlertOverlay
│           │   ├── status/StandaloneStatusScreen.kt  # ↔ StandaloneStatusView
│           │   └── theme/                       # cores (tempoOrange #FF6B35), tipografia
│           ├── workout/                        # ↔ Managers/WorkoutManager
│           │   ├── ExerciseManager.kt          # Health Services ExerciseClient
│           │   ├── WorkoutViewModel.kt         # estado idle/running/paused/ended
│           │   ├── WorkoutService.kt           # foreground service + Ongoing Activity
│           │   ├── LiveMetrics.kt              # ↔ struct LiveMetrics
│           │   ├── HeartRateZones.kt           # ↔ struct HeartRateZones
│           │   ├── SplitTracker.kt             # ↔ KmSplit + checkSplit
│           │   └── RacePredictions.kt          # ↔ Daniels & Gilbert
│           ├── connectivity/                   # ↔ WatchSessionManager
│           │   ├── DataLayerManager.kt         # MessageClient/DataClient (envia ao phone)
│           │   ├── WorkoutPayload.kt           # ↔ WorkoutPayload + SplitPayload (kotlinx.serialization)
│           │   └── WearListenerService.kt      # recebe credenciais/plano/complication do phone
│           ├── network/                        # ↔ Networking/
│           │   ├── SupabaseClient.kt           # Ktor → watch-workout-save + refresh
│           │   ├── OfflineQueue.kt             # Room DAO + entidade
│           │   ├── SyncWorker.kt               # WorkManager (retry/backoff)
│           │   └── NetworkMonitor.kt           # ConnectivityManager callback
│           ├── training/                       # ↔ Models/TrainingPlan + TrainingPlanManager
│           │   ├── TrainingPlan.kt             # WorkoutType, DailyWorkout, TrainingWeek, TrainingPlan
│           │   └── TrainingPlanRepository.kt   # cache DataStore + alerta de pace
│           ├── tiles/                          # ↔ WidgetBundle (Smart Stack)
│           │   └── TempoRunTileService.kt
│           ├── complications/                  # ↔ ComplicationProvider
│           │   └── TempoRunComplicationService.kt
│           └── data/
│               └── AppPrefs.kt                 # DataStore (credenciais, complication cache)
├── shared/                            # (opcional) modelos compartilhados wear↔plugin
│   └── ...                            # WorkoutPayload / TrainingPlan se reusados no phone
└── README.md
```

E, no lado do **celular** (no repo `temporun-app`, fora deste repo):

```
temporun-app/android/  (Capacitor)
└── capacitor-plugin TempoRunWear (Kotlin)
    ├── WearWorkoutListenerService   # ↔ PhoneSessionManager: recebe payload do relógio
    ├── WearPlanSync                  # ↔ PlanSyncToWatch: envia plano ativo
    └── WearCredentialSync            # ↔ CredentialSyncToWatch: envia tokens Supabase
```

---

## 5. Corte de paridade de features (o que vai no relógio)

| # | Feature (Apple Watch) | Vai no Wear OS? | API / Observação |
|---|------------------------|-----------------|------------------|
| **Núcleo de corrida** | | | |
| 1 | Iniciar/pausar/encerrar corrida | ✅ MVP | `ExerciseClient` (start/pause/resume/end) |
| 2 | Distância, pace atual/médio/melhor, velocidade | ✅ MVP | `DataType.DISTANCE_TOTAL`, `PACE`, `SPEED` |
| 3 | Duração (timer) | ✅ MVP | `ExerciseUpdate.activeDuration` |
| 4 | Passos, cadência | ✅ MVP | `STEPS_TOTAL`, `STEP_CADENCE` |
| 5 | FC atual/média/mín/máx | ✅ MVP | `HEART_RATE_BPM` |
| 6 | Zonas de FC (Z1–Z5) + tempo por zona | ✅ Fase 1 | cálculo local (mesma fórmula 50–100% maxHR) |
| 7 | Energia ativa/basal/total | ✅ Fase 1 | `CALORIES_TOTAL` (+ estimativa basal) |
| 8 | Altitude atual/máx/mín, ganho/perda | ✅ Fase 1 | `ELEVATION_GAIN/LOSS`, `ABSOLUTE_ELEVATION` |
| 9 | Lances subidos | ✅ Fase 1 | `FLOORS` (se disponível no device) |
| 10 | Rota GPS | ✅ Fase 1 | location do `ExerciseUpdate` / Fused Location |
| 11 | Splits por km + haptic | ✅ Fase 1 | `SplitTracker` local + `Vibrator` |
| 12 | Predição de prova (Daniels) | ✅ Fase 1 | cálculo local (depende de VO₂ máx) |
| **Biomecânica** | | | |
| 13 | Potência de corrida (W) | ⚠️ device-dependente | `DataType.POWER` (nem todo Galaxy Watch expõe) |
| 14 | Comprimento de passada | ⚠️ device-dependente | `STRIDE_LENGTH` (se suportado) |
| 15 | Tempo de contato com solo | ⚠️ device-dependente | `GROUND_CONTACT_TIME` (poucos devices) |
| 16 | Oscilação vertical / vertical ratio | ⚠️ device-dependente | `VERTICAL_OSCILLATION` (poucos devices) |
| 17 | Esforço físico (METs) | ⚠️ | sem equivalente direto — estimar ou ocultar |
| **Cardio avançado** | | | |
| 18 | HRV-SDNN | ⚠️ histórico | não medido durante exercício; ler do Health Connect |
| 19 | SpO₂ | ⚠️ histórico | medição passiva; não ao vivo na corrida |
| 20 | Frequência respiratória | ⚠️ histórico | idem |
| 21 | VO₂ máx, FC repouso | ✅ (leitura) | Health Connect no celular → enviar ao relógio |
| **Sincronização** | | | |
| 22 | Sync rico relógio→celular | ✅ Fase 2 | Data Layer (`DataClient` urgente / `MessageClient`) |
| 23 | Atualização ao vivo (pace/FC/dist) | ✅ Fase 2 | `MessageClient.sendMessage` a cada 5s |
| 24 | Standalone direto no Supabase | ✅ Fase 5 | Ktor → `watch-workout-save` |
| 25 | Fila offline + sync ao reconectar | ✅ Fase 5 | Room + WorkManager + NetworkCallback |
| 26 | Credenciais Supabase do celular | ✅ Fase 5 | Data Layer → DataStore |
| **Plano de treino** | | | |
| 27 | Treino do dia (tipo, dist, pace-alvo) | ✅ Fase 3 | recebe plano via Data Layer |
| 28 | Semana completa | ✅ Fase 3 | `WeekPlanScreen` |
| 29 | Alerta de pace fora da zona (haptic) | ✅ Fase 3 | `Vibrator` directionUp/Down + overlay |
| 30 | Treino estruturado/intervalos | 🔵 Fase 3+ | `ExerciseGoal`/milestones (avançado) |
| **Glanceability** | | | |
| 31 | Complications (km/streak/próx. treino) | ✅ Fase 4 | Complications Data Source |
| 32 | Smart Stack widget | ✅ Fase 4 | **Tiles** (Tile Service) |
| 33 | Notificação de treino ativo | ✅ Fase 1 | **Ongoing Activity** (obrigatório p/ background) |

**Legenda:** ✅ paridade · ⚠️ depende do hardware (degradar graciosamente: ocultar campo
quando o `DataType` não for suportado pelo device) · 🔵 stretch.

> **Decisão de produto a tomar:** a biomecânica avançada (13–17) e o cardio passivo
> (18–20) são onde o Wear OS perde para o Apple Watch. Recomendação: **detectar
> capacidades** via `ExerciseClient.getCapabilities()` e mostrar só o que o device
> entrega — em vez de telas com campos vazios. As métricas indisponíveis simplesmente
> não aparecem naquele relógio.

---

## 6. Comunicação com o celular — o ponto mais sensível

### 6.1. Inversão de caminhos vs. Apple Watch

No Apple Watch:
- **Caminho A (primário/MVP):** grava `HKWorkout` no HealthKit → iPhone importa sozinho.
- **Caminho B:** WatchConnectivity envia payload rico.
- **Standalone:** URLSession direto no Supabase.

No Wear OS **não existe o Caminho A** (sem store de saúde compartilhado relógio→celular
com import automático). Logo:

- **Caminho primário (Fase 2):** **Data Layer** — relógio envia `WorkoutPayload` ao celular
  via `DataClient.putDataItem(...).setUrgent()` (entrega garantida, sobrevive a desconexão,
  análogo ao `transferUserInfo`) **+** `MessageClient.sendMessage` quando o celular está
  acessível (entrega imediata, análogo ao `sendMessageData`). O celular (plugin Capacitor)
  recebe, monta o dict no schema `corridas` e chama a edge function ou insere via Supabase JS.
- **Caminho standalone (Fase 5):** relógio com rede própria → Ktor → `watch-workout-save`.
  Idêntico em espírito ao `SupabaseClient` do Apple.

### 6.2. Lado do celular (temporun-app, Capacitor)

`PhoneSessionManager` (Swift) → equivalente Android precisa ser um **Capacitor plugin
nativo em Kotlin** com `WearableListenerService` registrado no `AndroidManifest`:
- `onMessageReceived` / `onDataChanged` → decodifica `WorkoutPayload`
- converte para o schema `corridas` (mesmo mapeamento do `CorridaFromWatch.toSupabaseDict()`)
- duas opções de gravação:
  - **(a)** repassa para o JS (`temporun-app`) e reusa o fluxo de salvamento existente
    (XP, plano, vínculo) — preferível p/ manter uma única fonte de verdade no app;
  - **(b)** chama a edge function `watch-workout-save` direto do Kotlin — mais simples,
    funciona mesmo com o JS fechado.
- também precisa de `WearPlanSync` (enviar plano ativo) e `WearCredentialSync` (enviar
  tokens após login) — equivalentes a `PlanSyncToWatch`/`CredentialSyncToWatch`.

> Esse plugin Capacitor é a peça nova de maior risco/esforço, porque o `temporun-app` é um
> monolito React/Capacitor sem API nativa clara. Decidir cedo entre (a) e (b).

### 6.3. Pareamento de payload

`WorkoutPayload`/`SplitPayload` (Swift `Codable`) → **`@Serializable` data class** (kotlinx)
com os **mesmos nomes de campo** do contrato da seção 1.3, para que celular e edge function
não precisem de tradução adicional.

---

## 7. Fases de implementação

Espelham as fases do Apple Watch, adaptadas às realidades do Android.

### Fase 0 — Setup *(precisa de Android Studio)*
- [ ] Criar projeto Gradle em `samsung/` (módulo `wear`), Compose for Wear OS.
- [ ] `AndroidManifest`: permissões `BODY_SENSORS`, `ACTIVITY_RECOGNITION`,
      `ACCESS_FINE_LOCATION`, `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_HEALTH`,
      `POST_NOTIFICATIONS`, `WAKE_LOCK`; declarar `uses-feature android.hardware.type.watch`.
- [ ] Theme (preto OLED, `tempoOrange #FF6B35`, tipografia bold) — paridade visual.
- [ ] Workflow de CI (Codemagic Android ou GitHub Actions) gerando AAB.
- [ ] Decidir `applicationId`/track no Play Console (ver seção 8).

### Fase 1 — MVP "Corrida do pulso" (Health Services, sem rede)
- [ ] `ExerciseManager` com `ExerciseClient`: start/pause/resume/end, `getCapabilities()`.
- [ ] `WorkoutService` (foreground) + **Ongoing Activity** para gravar em background.
- [ ] `LiveMetrics` + coleta de distância, pace, velocidade, FC, passos, cadência.
- [ ] Zonas de FC + tempo por zona (cálculo local).
- [ ] Energia, altitude/elevação, rota GPS.
- [ ] `SplitTracker` + haptic por km; predição de prova (Daniels).
- [ ] UI: `StartScreen` → `LiveMetricsPager` (HorizontalPager, ~6–8 páginas) → `SummaryScreen`.
- [ ] Degradação graciosa de biomecânica conforme capacidade do device.
- [ ] Teste em **Galaxy Watch físico** (emulador não dá GPS/FC confiável).

### Fase 2 — Sincronização rica via Data Layer
- [ ] `DataLayerManager` no relógio: `DataClient.setUrgent()` (garantido) + `MessageClient`
      (imediato) + live update a cada 5s.
- [ ] `WorkoutPayload` `@Serializable` com schema da seção 1.3.
- [ ] **Plugin Capacitor** no `temporun-app`: `WearableListenerService` →
      schema `corridas` → grava (opção a ou b da seção 6.2).
- [ ] Live update no app do celular (tela de "corrida em andamento no relógio").

### Fase 3 — Integração com plano de treino
- [ ] `TrainingPlan.kt` (paridade com `TrainingPlan.swift`): 13 tipos, parse de
      `pace_alvo` "min:ss-min:ss/km", `isPaceOnTarget`, `todayWorkout`.
- [ ] `TrainingPlanRepository`: recebe plano via Data Layer, cache em DataStore,
      `requestPlanFromPhone()`.
- [ ] `TodayWorkoutScreen` + `WeekPlanScreen` + `PaceAlertOverlay`.
- [ ] Alerta de pace fora da zona (haptic directionUp/Down) durante a corrida.
- [ ] `WearPlanSync` no plugin Capacitor (envia plano ativo + responde request).
- [ ] (Stretch) treino estruturado via `ExerciseGoal`/milestones.

### Fase 4 — Complications + Tiles (glanceability)
- [ ] `TempoRunComplicationService` (`SuspendingComplicationDataSourceService`):
      SHORT_TEXT, LONG_TEXT, RANGED_VALUE, MONOCHROMATIC_ICON, SMALL_IMAGE — km semanal,
      streak, próximo treino (paridade conceitual com as 10 famílias do ClockKit).
- [ ] `TempoRunTileService` (Tiles Material): progresso semanal + barra + próximo treino
      (equivalente do Smart Stack widget).
- [ ] `ComplicationData`/`TileState` cache em DataStore; atualização via Data Layer do celular.
- [ ] `WearComplicationSync` no plugin (envia km/streak/xp/próx. treino).

### Fase 5 — Modo standalone
- [ ] `SupabaseClient.kt` (Ktor): `insertCorrida` → `watch-workout-save`, refresh de token.
- [ ] `OfflineQueue` (Room) + `SyncWorker` (WorkManager, backoff, max tentativas).
- [ ] `NetworkMonitor` (ConnectivityManager) → dispara sync ao reconectar.
- [ ] `WearCredentialSync` no plugin → tokens via Data Layer → DataStore no relógio.
- [ ] `StandaloneStatusScreen`: rede, credenciais, fila pendente, botão sync.
- [ ] `ExerciseManager.end()` decide: celular acessível → Data Layer; senão → Supabase/fila.

### Backend (pequeno, médio prazo)
- [ ] Estender dedup/merge para `wear_os`/`wear_os_standalone` (seção 9).
- [ ] (Opcional) edge functions `watch-sync-plan` e `complication-data` — já planejadas para
      o Apple, servem aos dois relógios.

---

## 8. Distribuição e contas

| Tema | Nota |
|------|------|
| Play Console | App de relógio entregue no mesmo app do celular (`com.temporun.run`) via *Wear OS app* embutido, ou como app standalone separado. Recomendado: mesmo package, entrega acoplada. |
| Health data org | Lembrete (CLAUDE.md): conta individual foi rejeitada para health data; **EmeraldWave Labs** registrada, DUNS solicitado. O Wear OS lê sensores de saúde → exige a conta de **organização** resolvida antes do release. |
| Permissões sensíveis | `BODY_SENSORS`/`ACTIVITY_RECOGNITION`/localização em background exigem justificativa na ficha do Play + Data Safety form. |
| Teste | Internal testing track; precisa de Galaxy Watch físico pareado. |
| CI | Codemagic suporta Android (workflow separado `temporun-watch-android`) ou GitHub Actions com Gradle + assinatura. |

---

## 9. Ajuste de backend necessário (pequeno)

Hoje o dedup e o merge só reconhecem dispositivos Apple. Adicionar os valores do Wear OS:

```sql
-- corridas_watch_dedup_idx → recriar incluindo wear_os
DROP INDEX IF EXISTS corridas_watch_dedup_idx;
CREATE UNIQUE INDEX IF NOT EXISTS corridas_watch_dedup_idx
  ON corridas (user_id, data_inicio)
  WHERE device IN ('apple_watch','apple_watch_standalone','wear_os','wear_os_standalone');
```
A função `merge_watch_corrida` é genérica (usa `p_payload->>'device'`), então só precisa que
o cliente Wear OS envie `device = 'wear_os'`/`'wear_os_standalone'` e `source` correspondente.
A coluna `device` na migração já documenta `'samsung_watch'` como valor possível — **padronizar
o nome** (`wear_os` vs `samsung_watch`) antes de codar para não divergir do `watch-sync-log`.

---

## 10. Pontos de atenção de engenharia

| Ponto | Detalhe |
|-------|---------|
| **Foreground service** | Sem ele a corrida para ao apagar a tela. É código novo sem equivalente no Apple. Tipo `health` (Android 14+). |
| **Capacidades por device** | Galaxy Watch ≠ Pixel Watch ≠ outros. Sempre checar `getCapabilities()`; nunca assumir biomecânica avançada. |
| **Plugin Capacitor (celular)** | Maior risco. O `temporun-app` é monolito React/Capacitor; precisa de ponte nativa Kotlin para o Data Layer. Decidir grava-no-JS vs. grava-na-edge-function cedo. |
| **Sem App Group** | Toda config (credenciais, plano) viaja pelo Data Layer; cache local separado por dispositivo. |
| **Métricas passivas** | HRV/SpO₂/respiração não vêm durante a corrida; ler do Health Connect (celular) e enviar, ou omitir. |
| **Padronizar `device`/`source`** | Alinhar `wear_os`/`wear_os_standalone` em relógio, plugin, edge function e SQL. |
| **Teste físico** | Galaxy Watch real obrigatório (emulador não simula GPS/FC/haptics de forma confiável). |
| **Bateria** | Foreground service + GPS + Compose redesenham bateria; usar `tabViewStyle`/recomposição enxuta e `setUrgent` com parcimônia. |

---

## 11. Recomendação de sequência

Igual ao Apple, **começar pelo núcleo de corrida**, mas com uma diferença: como o Wear OS
não tem o "Caminho A gratuito", a **Fase 2 (Data Layer)** vira parte do MVP de valor real —
sem ela a corrida fica presa no relógio. Ordem sugerida:

1. **Fase 0** — setup Gradle + manifest + theme + CI.
2. **Fase 1** — `ExerciseManager` + foreground service + 3 telas (Start/Live/Summary) +
   splits/haptics. *Validar "correr com o relógio".*
3. **Fase 2** — Data Layer + plugin Capacitor mínimo (caminho b: grava direto na edge
   function). *Validar "a corrida aparece no app do celular".*
4. **Fase 3** — plano de treino + alertas de pace.
5. **Fase 5** — standalone + fila offline.
6. **Fase 4** — complications + Tiles (glanceability é o polimento final).

> Diferença-chave vs. Apple: **Fase 2 sobe de prioridade** (entra no MVP), porque é o que
> traz a corrida do pulso para dentro do TempoRun.

---

## 12. Tabela-resumo de equivalências (cola rápida)

| Apple Watch | Wear OS |
|-------------|---------|
| `WorkoutManager` / HKWorkoutSession | `ExerciseManager` / `ExerciseClient` |
| `HKLiveWorkoutBuilder` (métricas) | `ExerciseUpdateCallback` (`ExerciseUpdate`) |
| `HKWorkoutRouteBuilder` + CLLocation | location do `ExerciseUpdate` / Fused Location |
| `WatchConnectivity` / `WCSession` | Wearable Data Layer (`MessageClient`/`DataClient`) |
| `transferUserInfo` (garantido) | `DataClient.putDataItem().setUrgent()` |
| `sendMessageData` (imediato) | `MessageClient.sendMessage` |
| `updateApplicationContext` (live) | `MessageClient.sendMessage` periódico |
| App Group UserDefaults | DataStore / Room (por dispositivo) |
| `URLSession` (standalone) | Ktor Client |
| `OfflineQueue` custom | Room + WorkManager |
| `NWPathMonitor` | `ConnectivityManager.NetworkCallback` |
| `ClockKit` complications | Wear OS Complications Data Source |
| WidgetKit Smart Stack | Tiles (Tile Service) |
| `WKInterfaceDevice.play(.success)` | `Vibrator` / `VibrationEffect` |
| WorkoutKit (estruturado) | `ExerciseGoal` / milestones |
| `PhoneSessionManager` (iOS) | `WearableListenerService` (plugin Capacitor Kotlin) |
| edge function `watch-workout-save` | **reusada sem mudança** (só estender dedup) |

---

*Próximo passo (amanhã): revisar este plano, decidir (a) grava-no-JS vs. (b) grava-na-edge-function
no plugin Capacitor, padronizar `device = 'wear_os'`, e então iniciar a Fase 0 do módulo `samsung/`.*
