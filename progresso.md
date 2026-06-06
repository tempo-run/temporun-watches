# Progresso de Implementação — TempoRun Watch App

---

## Fase 0 — Preparação
> Configuração do projeto, targets e CI

| Item | Status | Arquivo |
|------|--------|---------|
| Estrutura de pastas `apple/` e `samsung/` | ✅ | `apple/`, `samsung/` |
| `project.yml` (XcodeGen — gera .xcodeproj no Mac via CI) | ✅ | `apple/project.yml` |
| Target watchOS com bundle id `com.temporun.run.watchkitapp` | ✅ | `apple/project.yml` |
| Capability HealthKit habilitada | ✅ | `apple/TempoRunWatch/TempoRunWatch.entitlements` |
| `Info.plist` com permissões `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` | ✅ | `apple/TempoRunWatch/Info.plist` |
| `codemagic.yaml` com step `brew install xcodegen` + build watchOS | ✅ | `apple/codemagic.yaml` |

---

## Fase 1 — MVP "Corrida do pulso"
> Swift/SwiftUI nativo, sem backend, grava no HealthKit

### Arquitetura

| Arquivo | Responsabilidade | Status |
|---------|-----------------|--------|
| `TempoRunWatchApp.swift` | Entry point `@main`, injeta `WorkoutManager` | ✅ |
| `WorkoutManager.swift` | Toda a lógica de sessão, métricas, splits, zonas | ✅ |
| `Extensions.swift` | Formatadores de pace, duração, distância, tempo de prova | ✅ |
| `ContentView.swift` | Navegação por estado (`idle → running/paused → ended`) | ✅ |
| `StartView.swift` | Tela inicial com botão "Iniciar" | ✅ |
| `LiveMetricsView.swift` | 8 páginas de métricas ao vivo (TabView paginado) | ✅ |
| `SummaryView.swift` | Resumo completo pós-corrida por seção | ✅ |

### Métricas implementadas

#### Corrida
| Métrica | Fonte | Status |
|---------|-------|--------|
| Distância (km) | `HKQuantityType(.distanceWalkingRunning)` | ✅ |
| Pace atual (seg/km) | derivado de `runningSpeed` | ✅ |
| Pace médio (seg/km) | `elapsedTime / distanceKm` | ✅ |
| Melhor pace | mínimo histórico do pace instantâneo | ✅ |
| Velocidade atual (m/s) | `HKQuantityType(.runningSpeed)` | ✅ |
| Duração | timer interno | ✅ |
| Passos | `HKQuantityType(.stepCount)` | ✅ |
| Cadência (spm) | `stepCount / elapsedTime * 60` | ✅ |

#### Biomecânica (Running Dynamics)
| Métrica | Fonte | Status |
|---------|-------|--------|
| Comprimento de passada (m) | `HKQuantityType(.runningStrideLength)` | ✅ |
| Potência de corrida (W) | `HKQuantityType(.runningPower)` | ✅ |
| Tempo de contato com o solo (ms) | `HKQuantityType(.runningGroundContactTime)` | ✅ |
| Oscilação vertical (cm) | `HKQuantityType(.runningVerticalOscillation)` | ✅ |
| Vertical Ratio (%) | `(oscilação / passada) * 100` — igual ao Garmin | ✅ |
| Esforço físico (METs) | `HKQuantityType(.physicalEffort)` — watchOS 10+ | ✅ |

#### Cardio & Saúde
| Métrica | Fonte | Status |
|---------|-------|--------|
| Frequência cardíaca atual (bpm) | `HKQuantityType(.heartRate)` | ✅ |
| FC média | acumulado via `HKLiveWorkoutBuilder` | ✅ |
| FC mínima | acumulado ao vivo | ✅ |
| FC máxima | acumulado ao vivo | ✅ |
| FC de repouso | `HKQuantityType(.restingHeartRate)` (histórico) | ✅ |
| HRV — SDNN (ms) | `HKQuantityType(.heartRateVariabilitySDNN)` | ✅ |
| SpO₂ (%) | `HKQuantityType(.oxygenSaturation)` | ✅ |
| Frequência respiratória (r/min) | `HKQuantityType(.respiratoryRate)` | ✅ |
| VO₂ máx (ml/kg/min) | `HKQuantityType(.vo2Max)` | ✅ |
| Zona de FC atual (Z1-Z5) | `HeartRateZones` baseado em maxHR estimado | ✅ |
| Tempo em cada zona (seg) | acumulado via timer | ✅ |

#### Energia
| Métrica | Fonte | Status |
|---------|-------|--------|
| Energia ativa (kcal) | `HKQuantityType(.activeEnergyBurned)` | ✅ |
| Energia basal (kcal) | `HKQuantityType(.basalEnergyBurned)` | ✅ |
| Total de calorias | `ativa + basal` | ✅ |

#### Altitude & GPS
| Métrica | Fonte | Status |
|---------|-------|--------|
| Altitude atual (m) | `CLLocation.altitude` | ✅ |
| Altitude máxima (m) | acumulado via GPS | ✅ |
| Altitude mínima (m) | acumulado via GPS | ✅ |
| Ganho de elevação (m) | acumulado via GPS | ✅ |
| Perda de elevação (m) | acumulado via GPS | ✅ |
| Lances subidos | `HKQuantityType(.flightsClimbed)` | ✅ |
| Rota GPS | `HKWorkoutRouteBuilder` + `CLLocationManager` | ✅ |

#### Splits & Predições
| Item | Detalhe | Status |
|------|---------|--------|
| Splits por km | pace, FC média, ganho de elevação por km | ✅ |
| Vibração (haptic) a cada split | `WKInterfaceDevice.current().play(.success)` | ✅ |
| Preditor de prova | 5k, 10k, meia, maratona — fórmula Daniels & Gilbert | ✅ |

### Fluxo de sincronização (Caminho A)
- Corrida gravada via `HKWorkoutSession` + `HKLiveWorkoutBuilder`
- Rota salva via `HKWorkoutRouteBuilder`
- Ao encerrar: `HKWorkout` gravado no Apple Health
- O app iOS já importa automaticamente via `Health.queryWorkouts` (linha ~15881 do `TempoRun.jsx`) — **sem mudanças de backend necessárias**

---

## Fase 2 — Sincronização rica via WatchConnectivity
> Watch → iPhone: splits, cadência, potência, calorias no formato exato da tabela `corridas`

| Item | Status | Arquivo |
|------|--------|---------|
| `WatchSessionManager.swift` (Watch) — ativa WCSession, envia payload | ✅ | `apple/TempoRunWatch/.../Managers/WatchSessionManager.swift` |
| `PhoneSessionManager.swift` (iOS) — recebe e converte para schema `corridas` | ✅ | `apple/PhoneSessionManager.swift` |
| `WorkoutPayload` + `SplitPayload` — structs Codable com todas as métricas | ✅ | `WatchSessionManager.swift` |
| `CorridaFromWatch` — mapeamento para schema Supabase `corridas` + `toSupabaseDict()` | ✅ | `PhoneSessionManager.swift` |
| Envio imediato via `sendMessageData` quando iPhone acessível | ✅ | `WatchSessionManager.swift` |
| Fallback via `transferUserInfo` (garante entrega com iPhone offline) | ✅ | `WatchSessionManager.swift` |
| Atualização ao vivo a cada 5 s via `updateApplicationContext` (pace, FC, distância) | ✅ | `WorkoutManager.swift` |
| Recepção no iPhone via `didReceiveMessageData` + `didReceiveUserInfo` | ✅ | `PhoneSessionManager.swift` |
| Integração no `WorkoutManager.endWorkout()` — envia ao encerrar | ✅ | `WorkoutManager.swift` |

### Fluxo completo da Fase 2
```
Watch                                iPhone (temporun-app)
──────────────────────────────       ─────────────────────────────────
Corrida em andamento                 PhoneSessionManager.shared
  → a cada 5 s: liveUpdate    ──→    didReceiveApplicationContext
    (distância, pace, FC)              delegate.didReceiveLiveUpdate()
                                       → atualizar UI no app iOS

Ao encerrar:                         
  WorkoutPayload (Codable)    ──→    didReceiveMessageData
  com todas as métricas              CorridaFromWatch(from: payload)
  + splits + zonas + GPS             delegate.didReceiveWorkout()
                                       → toSupabaseDict()
  Se iPhone offline:                   → inserir na tabela `corridas`
  transferUserInfo (fila)    ──→       → vincular ao plano de treino
                                       → calcular XP
```

---

## Fase 3 — Integração com plano de treino
> Mostrar treino do dia no relógio, alertas de pace por zona

| Item | Status | Arquivo |
|------|--------|---------|
| `TrainingPlan.swift` — modelos: `WorkoutType`, `DailyWorkout`, `TrainingWeek`, `TrainingPlan` | ✅ | `apple/TempoRunWatch/.../Models/TrainingPlan.swift` |
| 13 tipos de treino mapeados (Rodagem, Longão, Qualidade, Recovery) | ✅ | `TrainingPlan.swift` |
| Parse de `pace_alvo` "min:ss-min:ss/km" → seg/km com tolerância ±5% | ✅ | `TrainingPlan.swift` |
| `isPaceOnTarget()` — status: ok / tooFast / tooSlow | ✅ | `TrainingPlan.swift` |
| `todayWorkout()` — seleciona sessão pelo dia da semana atual | ✅ | `TrainingPlan.swift` |
| `TrainingPlanManager.swift` — recebe plano, cache App Group, alertas | ✅ | `apple/TempoRunWatch/.../Managers/TrainingPlanManager.swift` |
| Cache local via `UserDefaults(suiteName: group.com.temporun.run)` | ✅ | `TrainingPlanManager.swift` |
| `checkPaceAlert()` — dispara haptic `directionUp/Down` fora da zona | ✅ | `TrainingPlanManager.swift` |
| `requestPlanFromPhone()` — solicita plano ao iPhone via `sendMessage` | ✅ | `TrainingPlanManager.swift` |
| `TodayWorkoutView.swift` — treino do dia com estrutura, pace-alvo, alerta de lesão | ✅ | `apple/TempoRunWatch/.../Views/TodayWorkoutView.swift` |
| `WeekPlanView.swift` — semana completa com destaque no dia atual | ✅ | `TodayWorkoutView.swift` |
| `PaceAlertOverlay.swift` — overlay animado com auto-dismiss 4s | ✅ | `apple/TempoRunWatch/.../Views/PaceAlertOverlay.swift` |
| `ContentView.swift` — 3 tabs em idle (Hoje / Semana / Livre) + overlay de alerta | ✅ | `ContentView.swift` |
| `PlanSyncToWatch.swift` (iOS) — serializa e envia plano via WC, responde request do Watch | ✅ | `apple/PlanSyncToWatch.swift` |
| `buildTransfer(from:)` — converte row do Supabase para struct Codable | ✅ | `PlanSyncToWatch.swift` |

### Fluxo completo da Fase 3
```
temporun-app (iPhone)                    Watch
──────────────────────────────           ──────────────────────────────
Plano ativo no Supabase                  TrainingPlanManager.shared
  planos_treino.semanas (JSONB)          ├─ cache em UserDefaults (App Group)
  ↓                                      ├─ todayWorkout() → DailyWorkout
PlanSyncToWatch.buildTransfer()          └─ weekWorkouts → [DailyWorkout]
  ↓
syncActivePlan()                         ContentView (idle):
  updateApplicationContext     ──────→   Tab "Hoje": TodayWorkoutView
  (Watch por perto)                        - tipo, distância, pace-alvo
                                           - breakdown da sessão
  transferUserInfo             ──────→     - alerta de lesão (se houver)
  (Watch offline)                          - botão "Iniciar treino"

Watch solicita manualmente:              Tab "Semana": WeekPlanView
  requestPlanFromPhone()       ──────→     - 7 dias com destaque no atual
  sendMessage("trainingPlan")  ←──────   Tab "Livre": StartView

Durante a corrida:                       
  WorkoutManager atualiza pace           
  → planManager.checkPaceAlert()         
    - tooFast: haptic directionUp        
    - tooSlow: haptic directionDown      
    - overlay PaceAlertOverlay (4s)      
```

---

## Fase 4 — Complicações / Glanceability

| Item | Status |
|------|--------|
| Complicação na watch face (streak, XP, próximo treino) | ⏳ planejado |
| Widget no Smart Stack | ⏳ planejado |

---

## Fase 5 — Modo standalone (opcional)

| Item | Status |
|------|--------|
| GPS sem iPhone por perto | ⏳ planejado |
| Sync direto com Supabase via URLSession Swift | ⏳ planejado |
| Fila offline + sync posterior | ⏳ planejado |

---

## Samsung / Wear OS

| Item | Status |
|------|--------|
| Estrutura `samsung/` criada | ✅ |
| Implementação | ⏳ planejado |

---

**Legenda:** ✅ Concluído · 🔄 Em andamento · ⏳ Planejado
