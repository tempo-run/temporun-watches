# Auditoria do contrato de payload — corridas do relógio

> Auditoria multi-agente (extração por superfície + verificação adversarial com citações)
> executada em 2026-06-09. Contrato de referência: `interface WatchWorkoutPayload` da edge
> function `watch-workout-save` (`apple/supabase/functions/watch-workout-save/index.ts`).
> O endpoint **responde** no projeto Supabase (preflight `OPTIONS` → HTTP 204). Observação:
> esse 204 vem do tratamento de CORS da plataforma Supabase (o handler local devolve `"ok"`
> com status 200), então confirma que a rota existe — **não** garante que o código deployado
> é idêntico ao deste repo. Antes do go-live do Wear, redeployar a função com o patch do
> `sync_mode` para alinhar deployado ↔ repo.

## Resumo

| Superfície | Resultado |
|---|---|
| `apple/.../WorkoutManager.swift` (`saveStandalone`) | 🔴 **6 chaves erradas** → NULL silencioso no banco — **corrigido nesta branch** |
| `apple/PhoneSessionManager.swift` (`toSupabaseDict`) | 🔴 mesmas 6 chaves erradas; além disso o dict **não serve para INSERT direto** (11 chaves seriam coluna desconhecida → HTTP 400) — **corrigido + comentário** |
| Edge function → colunas do INSERT | ✅ todas as colunas existem (migração + schema base) |
| `samsung/.../WorkoutPayload.kt` (`toSupabaseMap`) | ✅ **0 divergências** (há teste de regressão: `WorkoutPayloadContractTest`) |

## Os 6 bugs confirmados (perda silenciosa de dados)

Mecânica: a edge function lê `payload.<nome_do_contrato>`; chave enviada com outro nome →
`undefined` no Deno → coluna NULL (supabase-js descarta `undefined`). Nenhum erro é gerado.

| Chave enviada (errada) | Contrato (correto) | Efeito no banco |
|---|---|---|
| `ground_contact_time` | `ground_contact` | `corridas.ground_contact` NULL |
| `vertical_oscillation` | `vertical_osc` | `corridas.vertical_osc` NULL |
| `frequencia_cardiaca_media` | `bpm_medio` | **pior caso:** `Math.round(undefined)` = `NaN` → serializado como `null` explícito → FC média some do histórico |
| `frequencia_cardiaca_min` | `fc_min` | `corridas.fc_min` NULL |
| `frequencia_cardiaca_max` | `fc_max` | `corridas.fc_max` NULL |
| `frequencia_respiratoria` | `frequencia_resp` | `corridas.frequencia_resp` NULL |

Afetava **os dois caminhos** do Apple Watch: standalone (`WorkoutManager.saveStandalone`) e
relay via iPhone (`PhoneSessionManager.toSupabaseDict`). Corrigido nesta branch
(`claude/wear-os-plan`). ⚠️ A branch ativa do Apple Watch
(`claude/peaceful-noether-VC4aB`) precisa do mesmo fix — chip/tarefa criada.

## Chaves que são REMAPEADAS pela edge function (corretas no contrato, erradas p/ insert direto)

`cadencia`→`cadencia_media` · `calorias_total`→`calorias` · `ganho_elevacao`→`dplus` ·
`perda_elevacao`→`elevacao_perda` · `step_count`→(aceito e descartado; tabela não tem a coluna).
Conclusão operacional: **sempre gravar via edge function** (decisão D1), nunca INSERT direto
com esse dict.

## Wear OS (Kotlin)

`toSupabaseMap()` segue o contrato à risca: 0 chaves fora do contrato (o extra `device` é
deliberado e inofensivo — a função destrutura só os campos conhecidos). Campos do contrato
que o Wear **não envia** (e ficam NULL por design, Health Services 1.0.0 não fornece):
`physical_effort`, `fc_repouso`, `hrv_sdnn`, `spo2`, `frequencia_resp` — e os opcionais de
plano (`plano_id`, `plano_semana`, `treino_tipo`, TODO Fase 3).

**NULL, não 0:** a biomecânica avançada (`stride_length`, `running_power`, `ground_contact`,
`vertical_osc`, `vertical_ratio`) é **omitida** do mapa quando não há leitura — a chave nem é
enviada, então a coluna fica NULL no banco em vez de receber 0 (que mascararia "sem sensor"
como "valor zero"). Travado pelo teste `WorkoutPayloadContractTest`. `velocidade_media` é a
média real (distância/tempo), não a velocidade instantânea do fim da corrida.

## Achados da revisão — corrigidos nesta branch

Revisão adversarial multi-agente (3 dimensões) do diff da Fase 1. Corrigidos:

- **Sessão órfã no swipe-to-dismiss** → posse movida para `WorkoutSessionHolder` (escopo de
  Application); a corrida sobrevive à morte/recriação da UI. Reanexa via
  `getCurrentExerciseInfoAsync()` (`restoreIfActive`).
- **Permissão negada → RUNNING fantasma** → `ExerciseManager.start()` filtra DataTypes por
  permissão concedida; `start()` aborta e não entra em RUNNING se o exercício falhar.
- **Duração com drift/congelamento** → derivada do `activeDurationCheckpoint` + `elapsedRealtime`
  (sobrevive a deep sleep); o tick de 1 s só interpola.
- **`START_STICKY` zumbi** → `START_NOT_STICKY` + guarda de intent nulo no serviço.
- **Biomecânica gravada como 0** → omitida (NULL). **`velocidade_media` instantânea** → média.
- **`pace_melhor` com spike de GPS** → teto de 2:00/km. **Sentinela de altitude 0 m** →
  flag `altitudeSeen`. **`end()`** reordenado (despacha antes de parar o FGS) + guarda de
  duplo-toque. **Callback do Health Services** limpo no `end()`.

## Achados deferidos (follow-up, não bloqueiam Fase 1)

- `cadencia`/`velocidade` são instantâneas no Apple Watch também (semântica pré-existente).
- `CALORIES_TOTAL` do Health Services inclui BMR mas é rotulado `calorias_ativas` — rótulo a
  revisar quando o Health Connect fornecer ativa/basal separadas.
- Salto > 1 km entre updates fecha um único split (raro; melhorar com laço por km).
- FC durante pausa pode contaminar média do split (sem guarda de pausa no callback).
- `onAvailabilityChanged` ignorado (tempo em zona pode somar com FC obsoleta se o sensor perde
  contato).

## Pendências de backend (rodar no Supabase)

1. `samsung/supabase/wear_migration.sql` — estende dedup p/ `wear_os` + permite
   `sync_mode='datalayer'` no `watch_sync_log`.
2. Redeploy da edge function com o patch do `sync_mode` (este repo já contém o diff).
   Ordem: migração SQL **antes** do redeploy.
