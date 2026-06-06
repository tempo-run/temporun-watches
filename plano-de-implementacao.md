# Plano de Implementação — TempoRun Watch App

---

## 1. Estrutura atual do app iOS (temporun-app)

### Stack
- React 18 + Vite + Capacitor 8 (app híbrido web/iOS/Android)
- Backend: Supabase (auth, banco, edge functions)
- IA: Claude Haiku via Supabase Edge Functions
- CI/CD: Codemagic (mobile) + Vercel (web)
- Pagamentos: RevenueCat + Apple IAP

### Arquitetura
Todo o app vive em um único arquivo: `src/TempoRun.jsx` (~27 mil linhas). Não há separação em componentes/hooks/telas em arquivos distintos. Modularização está em andamento, mas é gradual.

### Telas / Tabs do app

| Tab | Descrição |
|-----|-----------|
| **Home** | Dashboard principal com streak, XP, metas diárias e treino do dia |
| **Run** | Rastreamento de treino ativo (GPS, métricas em tempo real, mapa) |
| **Explore** | Funcionalidades sociais, descoberta de rotas |
| **Studio** | Biblioteca de vídeos e conteúdo de treino |
| **Science** | Análise biomecânica e insights fisiológicos |
| **Report** | Resumos e relatórios de performance |
| **Profile** | Conta do usuário e configurações / assinatura Pro |

### Ícones SVG disponíveis (componente `Ic()`)

`home`, `run`, `explore`, `studio`, `science`, `report`, `profile`, `back`, `share`, `send`, `save`, `sound`, `warning`, `check`, `injury`, `bars`, `settings`, `pro`, `bolt`, `bio`, `nutrition`, `sleep`, `flame`, `streak`, `upload`, `video`, `chart`, `mountain`, `trophy`, `star`, `pin`, `link`, `medal`, `photo`, `bib`, `gps`, `users`, `shoe`, `ai`, `watch`, `map`, `heart`, `calendar`, `book`, `lock`, `bulb`, `sync`, `trash`, `move`, `cadence`

### Métricas de corrida disponíveis

| Métrica | Unidade |
|---------|---------|
| `pace` | min/km |
| `cadencia` / `step_rate` | passos/min |
| `frequencia_cardiaca` / `heart_rate` | bpm |
| `distancia_km` | km |
| `duracao_seg` | segundos |
| `velocidade` / `speed` | m/s ou km/h |
| `elevacao` / `elevation` | metros |
| `vdot` / `vo2_estimado` | estimativa aeróbica (modelo Daniels) |
| `calorias` | kcal estimado |
| `polyline` | rota GPS codificada |

### Sistema de plano de treino (IA)

| Constante | Função |
|-----------|--------|
| `SYS_COACH` | Coach pessoal — fisiologia esportiva, biomecânica, nutrição, prevenção de lesões |
| `SYS_PLAN` | Gera semanas de treino; aplica regra dos 10%/semana, paces por VDOT, 8 tipos de treino |
| `SYS_PLAN_MACRO` | Estrutura macro de múltiplas semanas com progressão de volume (Daniels) |
| `SYS_PLAN_WEEK` | Expande uma semana em 7 treinos diários com distâncias exatas, paces e detalhes |

Base científica: Daniels & Gilbert (1979), Stoggl & Sperlich (2014), Bosquet et al. (2007).

### Banco de dados (Supabase)

| Tabela | Conteúdo |
|--------|----------|
| `corridas` | Corridas gravadas (GPS, splits, métricas, polyline) |
| `planos_treino` | Planos de treino gerados por IA |
| `provas_usuario` | Provas / corridas de rua do usuário |
| `recordes_pessoais` | PRs por distância |
| `rotas_favoritos` | Rotas favoritas |
| `rotas_seguras` | Rotas seguras (community) |
| `analises_bio` | Análises biomecânicas |
| `coach_mensagens` | Histórico de mensagens do coach de IA |
| `subscriptions_iap` | Assinaturas / compras in-app |
| `user_data` | Dados e preferências do usuário |

### Gravação de corrida (relevante para o Watch)
- `startGPS` / `startBackgroundGPSWatcher` — `TempoRun.jsx:14258`
- Haptics em `vibrateWorkout` — `TempoRun.jsx:13546` (padrões: split, fim de treino, fueling)
- Import do Apple Health: `Health.queryWorkouts`, `queryWorkoutRoute`, `readSamples` — `TempoRun.jsx:15881-15964`
- Entitlement HealthKit já habilitado (`App.entitlements`); `Info.plist` já pede `NSHealthShareUsageDescription` e `NSHealthUpdateUsageDescription`

---

## 2. Realidade técnica que muda tudo

watchOS **não roda WebView/Capacitor**. Não dá para reaproveitar o React/JS — é necessário um target nativo separado em Swift/SwiftUI dentro do mesmo projeto Xcode (`ios/App/App.xcodeproj`), usando HealthKit/WorkoutKit/CoreLocation/WatchConnectivity. É essencialmente um segundo app, em outra stack, que precisa "conversar" com o TempoRun existente.

---

## 3. Achado-chave: sincronização "de graça"

O TempoRun já lê workouts do Apple Health automaticamente. Se o app do Watch gravar a corrida via `HKWorkoutSession`/`HKLiveWorkoutBuilder` e salvar no HealthKit ao final, o fluxo de importação existente (linha ~15881) traz essa corrida para o histórico **sem precisar tocar no backend**. Esse é o caminho de menor esforço para o MVP.

---

## 4. Plano de Fases

### Fase 0 — Preparação *(precisa de Mac + Xcode)*

- [ ] Criar o target watchOS (`"TempoRun Watch App"`) no Xcode — não é gerado por `cap sync`, precisa ser adicionado manualmente.
- [ ] Configurar **App Group** compartilhado entre iOS app e Watch app (para troca local de dados/configurações).
- [ ] Habilitar capability **HealthKit** para o novo target; novo bundle id (`com.temporun.run.watchkitapp`).
- [ ] Adicionar scheme/target ao `codemagic.yaml`.

---

### Fase 1 — MVP "Corrida do pulso"

**Telas SwiftUI:**
- [ ] Tela de início: botão "Iniciar corrida" + status de conexão com iPhone
- [ ] Tela ao vivo: distância, duração, pace atual/médio, FC (layout compatível com tela redonda do Watch)
- [ ] Tela de pausa: botões pausar / continuar / encerrar
- [ ] Tela de resumo pós-corrida: distância total, tempo, pace médio, FC média

**Funcionalidades:**
- [ ] `HKWorkoutSession` + `HKLiveWorkoutBuilder` capturando GPS e frequência cardíaca direto do sensor do relógio
- [ ] Vibração nos splits de km (espelhando os padrões de `vibrateWorkout`: `WKInterfaceDevice.current().play(.success)`)
- [ ] Ao terminar: grava o `HKWorkout` (com rota via `HKSeriesBuilder`) no Health → cai automaticamente no histórico pelo import existente

> **Caminho A** — sem mudanças de backend. Menor esforço, maior retorno.

---

### Fase 2 — Sincronização rica via WatchConnectivity

- [ ] Watch envia ao iPhone splits/laps formatados, cadência, calorias — no formato exato da tabela `corridas`
- [ ] iPhone recebe via `WCSession` e grava reaproveitando o fluxo de salvamento existente
- [ ] Preserva vínculo com plano de treino (`planos_treino`) e cálculo de XP

> **Caminho B** — mais trabalho, mais fidelidade aos dados que o app já trata.

---

### Fase 3 — Integração com o plano de treino

- [ ] Repassar "treino de hoje" (`SYS_PLAN_WEEK`) do iPhone para o Watch via WatchConnectivity / App Group
- [ ] Mostrar no Watch: tipo de treino, distância-alvo, pace-alvo por zona (Z1-Z6 VDOT)
- [ ] Treino guiado/estruturado (intervalos, zonas) via **WorkoutKit** (watchOS 10+)
- [ ] Alertas por vibração quando pace sai da zona-alvo (`buildRunDetailVDOTZoneModel`)

---

### Fase 4 — Complicações / glanceability

- [ ] Complicação na watch face: progresso semanal de km, streak, XP, próximo treino
- [ ] Widget no Smart Stack com resumo do dia e meta

---

### Fase 5 — Modo standalone *(opcional, avançado)*

- [ ] Gravar sem iPhone por perto (GPS do relógio + celular LTE)
- [ ] Sincronizar direto com Supabase via URLSession nativo em Swift
- [ ] Fila offline + sync posterior quando iPhone reconectar

---

## 5. Design do Watch — princípios de UI

O app principal usa identidade visual escura, com acentos em laranja/vermelho e tipografia bold. No Watch:

- Fundo preto (nativo watchOS, poupa bateria no OLED)
- Cor primária: laranja `#FF6B35` (mesma do app iOS)
- Fonte: SF Pro Rounded (nativa watchOS, próxima do estilo do app)
- Métricas principais em fonte grande (40–60pt), secundárias em 16–20pt
- Ícones reutilizados conceitualmente: `heart`, `run`, `chart`, `gps` (recriados em SF Symbols equivalentes)

---

## 6. Pontos de atenção de engenharia

| Ponto | Detalhe |
|---|---|
| **Stack nova** | Swift/SwiftUI — não dá para reusar componentes React |
| **Teste real** | Simulador não reproduz GPS/FC/haptics de forma confiável — precisa de Apple Watch físico + TestFlight |
| **Gating Pro** | Decidir se o Watch é recurso exclusivo de assinantes (ligar com `subscriptionApi` via WatchConnectivity) |
| **Apple Developer** | Nova capability/App ID e perfil de provisionamento para o Watch target |
| **Monolito** | `TempoRun.jsx` não tem API pública clara — o receptor WatchConnectivity no iOS precisa ser adicionado em Swift, chamando o fluxo JS via Capacitor ou duplicando lógica de salvamento |

---

## 7. Recomendação de sequência

Começar pela **Fase 1 com o Caminho A** (grava no HealthKit → aproveita o import já existente): menor esforço, maior retorno, valida a experiência de "correr com o relógio" antes de investir em sincronização rica e integração com o plano de treino.

**Ordem sugerida de implementação da Fase 1:**
1. Fase 0 — setup do target Xcode (feito uma vez, no Mac)
2. `WorkoutManager.swift` — classe central gerenciando `HKWorkoutSession` + `HKLiveWorkoutBuilder`
3. `ContentView.swift` — navegação entre telas (início → ao vivo → resumo)
4. `LiveMetricsView.swift` — tela ao vivo com distância, pace, FC, tempo
5. `SummaryView.swift` — tela de resumo pós-corrida
6. Haptics nos splits
7. Teste em dispositivo físico + TestFlight
