# Decisões de arquitetura — TempoRun Wear OS

Registro das decisões tomadas durante a implementação, conforme o `WEAR_OS_PLAN.md`.

---

## D1 — Persistência: gravar-na-edge-function (Caminho **b**)  ✅ decidido

**Decisão:** quando o relógio envia a corrida ao celular (via Data Layer) ou grava em modo
standalone, o destino é **sempre uma edge function Supabase** — nunca um INSERT cru na tabela
nem uma ponte para o JavaScript do `temporun-app`.

> **Atualização:** o Wear usa uma função **separada**, `watch-workout-save-samsung` (mesma
> lógica da do Apple; só o `sync_mode` reconhece a origem Wear). Assim a função do Apple
> `watch-workout-save` fica intacta e o deploy do Wear é independente. Ver `supabase/BACKEND_DEPLOY.md`.

No lado do celular, o plugin Capacitor (`WearableListenerService`) recebe o `WorkoutPayload`
e **chama a mesma edge function** (não repassa para o WebView/JS).

**Por quê (vs. gravar-no-JS, Caminho a):**

1. **Funciona com o app fechado.** O `WearableListenerService` é nativo e roda mesmo quando
   o WebView Capacitor não está ativo. Gravar-no-JS exigiria o app aberto e o runtime React vivo.
2. **Fonte única de verdade no servidor.** A edge function já calcula XP (`km*45 + min*2`),
   streak (semanas únicas), recordes pessoais (12 distâncias) e faz deduplicação (±30s) de
   forma atômica. Reusar isso evita reimplementar a lógica em Kotlin **e** em JS.
3. **Não acopla ao monólito.** O `TempoRun.jsx` (~27k linhas) não tem API pública clara; uma
   ponte JS seria frágil.
4. **Mesma rota do modo standalone.** Relógio-standalone e celular-recebe usam exatamente o
   mesmo endpoint → uma superfície de código, um formato de payload, um ponto de teste.

**Trade-off aceito:** o app JS não é notificado em tempo real do save. Se a UI precisar
reagir na hora (ex.: animação de RP), resolvemos depois com um evento leve do plugin para o
JS, ou um realtime/refetch do Supabase. Não bloqueia o MVP.

---

## D2 — Identificador de dispositivo: `device = 'wear_os'`  ✅ decidido

- Corrida recebida pelo celular: `source = "wear_os"`.
- Corrida gravada em modo standalone: `source = "wear_os_standalone"`.

Alinhado com `apple_watch` / `apple_watch_standalone`. O backend ganha um índice de dedup
**separado** para o Wear (não altera o do Apple) — ver `WEAR_OS_PLAN.md` §9, a migração
`samsung/supabase/wear_migration.sql` e a análise de impacto no save do celular em
`samsung/supabase/BACKEND_DEPLOY.md`. A coluna `device` da
migração citava `'samsung_watch'` como exemplo — **padronizamos em `wear_os`** (cobre todos os
relógios Wear OS, não só Samsung).

---

## D3 — Toolchain: clássico estável (AGP 8.x), não AGP 9  ✅ decidido (revisado)

**Tentativa inicial** foi alinhar ao app do celular (Gradle 9.4.1 + AGP 9.2.1). O build
**falhou**: o AGP 9.0+ traz **Kotlin embutido** e rejeita o plugin clássico
`org.jetbrains.kotlin.android` (erro: *"no longer required since AGP 9.0"*). A configuração
de Compose/serialization nesse novo modelo ainda não é documentada de forma confiável.

**Decisão:** usar um stack consolidado e conhecido para o módulo Wear. Como os módulos são
**builds Gradle independentes**, não há obrigação de espelhar o AGP do celular — só o
`applicationId` precisa coincidir (para o Data Layer).

| Item | Valor | Nota |
|------|-------|------|
| Gradle | 8.14.3 | distribuição já em cache (build offline) |
| Android Gradle Plugin | 8.13.2 | último 8.x estável; usa o plugin Kotlin clássico |
| Kotlin | 2.0.21 | + compose compiler plugin 2.0.21 |
| Compose BOM | 2024.12.01 | Compose 1.7.x |
| Wear Compose | 1.4.1 | estável, pareado com Compose 1.7 |
| `applicationId` | `com.temporun.run` | **igual** ao celular (obrigatório p/ Data Layer parear apps companheiros) |
| `namespace` | `com.temporun.run.wear` | separa R/BuildConfig do módulo |
| compileSdk | 35 | instalado no SDK local |
| minSdk | 30 | Wear OS 3 (mínimo p/ Health Services) |
| targetSdk | 35 | Wear OS moderno |
| JDK alvo | 17 | (build roda em JDK 21) |

> Follow-up possível: migrar para AGP 9 + Kotlin embutido quando o fluxo de Compose
> estiver documentado/estável.

---

## D4 — UI: Wear Compose **Material** estável (1.6.2), não Material 3 (alpha)  ✅ decidido

O `WEAR_OS_PLAN.md` mencionava Material 3. Na prática, `androidx.wear.compose:compose-material3`
ainda está em **alpha** (API instável). Para um esqueleto que compila e serve de fundação
sólida, usamos **`compose-material` 1.6.2 (estável)**. Migração para Material 3 fica como
follow-up quando estabilizar — a estrutura de telas não muda, só os componentes visuais.

---

## D5 — Bibliotecas das fases adiadas entram quando a fase começar

Para manter a Fase 0 enxuta e o build estável, **Ktor (rede), Room (fila offline), WorkManager,
Tiles e Complications** só entram no `build.gradle.kts` quando suas fases (5 e 4) começarem.
Os arquivos correspondentes existem como **stubs documentados** com `TODO(Fase X)`.
