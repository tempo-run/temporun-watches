# Plano de Implementação — TempoRun Watch App

## O que existe hoje (relevante para o Watch)

- **Stack:** React + Capacitor (híbrido), com a maior parte da lógica ainda em `TempoRun.jsx` (~27 mil linhas, em modularização gradual).
- **Gravação de corrida:** GPS ao vivo (`startGPS`/`startBackgroundGPSWatcher`, `TempoRun.jsx:14258`), com mapa, splits, laps, pace, FC, cadência, potência, calorias, ganho de elevação e XP — tudo persistido na tabela `corridas` do Supabase (`corridas_schema.sql`).
- **Apple Health hoje é só leitura:** o app já usa `@capgo/capacitor-health` para importar treinos do Apple Health/Health Connect — `Health.queryWorkouts`, `queryWorkoutRoute`, `readSamples` (`TempoRun.jsx:15881-15964`). Não grava nada no Health ainda, mas o entitlement HealthKit já está habilitado (`App.entitlements`) e o `Info.plist` já pede `NSHealthShareUsageDescription`/`NSHealthUpdateUsageDescription`.
- **Haptics** já modelados em `vibrateWorkout` (`TempoRun.jsx:13546`) — padrões para split, fim de treino, fueling.
- **Plano de treino** com prescrições, zonas (modelo VDOT), metas diárias (`useTrainingPlan.js`).
- **Pro/assinatura** via RevenueCat + Stripe + Apple IAP (`subscriptionApi`).
- **CI** no Codemagic já builda o app iOS via `xcodebuild -project ios/App/App.xcodeproj -scheme App`.

---

## Realidade técnica que muda tudo

watchOS **não roda WebView/Capacitor**. Não dá para reaproveitar o React/JS — é necessário um target nativo separado em Swift/SwiftUI dentro do mesmo projeto Xcode (`ios/App/App.xcodeproj`), usando HealthKit/WorkoutKit/CoreLocation/WatchConnectivity. É essencialmente um segundo app, em outra stack, que precisa "conversar" com o TempoRun existente.

---

## Achado-chave: caminho de sincronização "de graça"

Como o TempoRun já lê workouts do Apple Health automaticamente, se o app do Watch simplesmente gravar a corrida via `HKWorkoutSession`/`HKLiveWorkoutBuilder` e salvar no HealthKit ao final, o fluxo de importação que já existe (linha ~15881) traz essa corrida para o histórico **sem precisar tocar no backend**. Esse é o caminho de menor esforço para o MVP.

---

## Plano de Fases

### Fase 0 — Preparação *(precisa de Mac + Xcode)*

- [ ] Criar o target watchOS (`"TempoRun Watch App"`) no Xcode — não é gerado por `cap sync`, precisa ser adicionado manualmente.
- [ ] Configurar **App Group** compartilhado entre iOS app e Watch app (para troca local de dados/configurações).
- [ ] Habilitar capability **HealthKit** para o novo target; novo bundle id (`com.temporun.run.watchkitapp`).
- [ ] Adicionar scheme/target ao `codemagic.yaml`.

---

### Fase 1 — MVP "Corrida do pulso"

- [ ] Tela SwiftUI de iniciar / pausar / parar corrida.
- [ ] Sessão `HKWorkoutSession` + `HKLiveWorkoutBuilder` capturando GPS e frequência cardíaca direto do sensor do relógio.
- [ ] Tela ao vivo: distância, duração, pace atual/médio, FC.
- [ ] Vibração nos splits de km (espelhando os padrões de `vibrateWorkout`).
- [ ] Ao terminar: grava o `HKWorkout` (com rota) no Health → cai automaticamente no histórico do TempoRun pelo import já existente.

> **Caminho A** — sem mudanças de backend. Menor esforço, maior retorno.

---

### Fase 2 — Sincronização rica via WatchConnectivity

- [ ] Watch envia ao iPhone splits/laps formatados, cadência, potência, calorias — no formato exato do schema `corridas`.
- [ ] iPhone recebe via `WCSession` e grava reaproveitando `corridasApi`/fluxo de salvamento existente, preservando vínculo com o plano de treino e cálculo de XP.

> **Caminho B** — mais trabalho, mais fidelidade aos dados que o app já trata bem.

---

### Fase 3 — Integração com o plano de treino

- [ ] Mostrar o "treino de hoje" (prescrição/paces-alvo) no relógio, repassado do iPhone.
- [ ] Treino guiado/estruturado (intervalos, zonas) no relógio via **WorkoutKit** (watchOS 10+).
- [ ] Alertas por vibração comparando o pace atual com a zona-alvo do plano.

---

### Fase 4 — Complicações / glanceability

- [ ] Complicação na watch face com progresso semanal, streak, XP, próximo treino.
- [ ] Widget no Smart Stack.

---

### Fase 5 — Modo standalone *(opcional, mais avançado)*

- [ ] Gravar sem o iPhone por perto (GPS + celular do relógio).
- [ ] Sincronizar direto com o Supabase (precisa de uma camada de rede nativa em Swift — não existe Capacitor lá).
- [ ] Fila offline + sync posterior.

---

## Pontos de atenção de engenharia

| Ponto | Detalhe |
|---|---|
| **Stack nova** | Swift/SwiftUI — equipe/tempo dedicado, não dá para reusar componentes React |
| **Teste real** | Simulador não reproduz GPS/FC/haptics de forma confiável — precisa de Apple Watch físico + TestFlight |
| **Gating Pro** | Decidir se o app do Watch é recurso exclusivo de assinantes (ligar com `subscriptionApi`) |
| **Apple Developer** | Nova capability/possível novo App ID e perfil de provisionamento |

---

## Recomendação de sequência

Começar pela **Fase 1 com o Caminho A** (grava no HealthKit → aproveita o import já existente): menor esforço, maior retorno, valida a experiência de "correr com o relógio" antes de investir em sincronização rica e integração com o plano de treino.
