# Backend — runbook de deploy (Wear OS)

Projeto Supabase: **`dxfgmzaxplarrwcmbotp`**. Estado verificado em 2026-06-09:

- A edge function **`watch-workout-save` JÁ está deployada e live** (probe `POST` sem auth →
  HTTP 401 do gateway com Verify-JWT; uma função inexistente daria 404). Ela **não** está em
  `temporun-app/supabase/functions/` — foi deployada direto do repo de relógios.
- O patch do `sync_mode` (reconhecer origem Wear) está no código deste repo, **ainda não
  deployado**.

> **Ordem obrigatória:** (1) migração SQL → (2) redeploy da função. Se a função subir antes,
> o `INSERT` em `watch_sync_log` com `sync_mode='datalayer'` viola o CHECK e o log é perdido
> (a corrida em si é salva — o log é best-effort).

---

## Impacto no save do celular (análise — por que NÃO quebra a gravação)

Auditado o caminho de gravação do `temporun-app` (`corridas-bulk-upsert/index.ts`,
`corridas_schema.sql`, `corridas_source_providers_2705.sql`). A migração do Wear é segura:

| Risco | Verdito | Evidência |
|-------|---------|-----------|
| Constraint em `source` rejeitar `'wear_os'` | ✅ sem risco | `source` é texto livre — `corridas_source_check` é **dropada** no schema (`corridas_schema.sql:39`, `corridas_source_providers_2705.sql:7`). Comentário: "Source must remain flexible". |
| Índice de dedup colidir com o upsert do celular | ✅ sem risco | O celular usa `upsert(onConflict:"id")` (a PK). O índice do Wear é em `(user_id, data_inicio)`. |
| Corrida do celular cair no índice parcial do Wear | ✅ sem risco | O celular grava `device=NULL` e não preenche `data_inicio` → fica FORA do `WHERE device IN ('wear_os',...)`. |
| Migração dropar/alterar algo existente | ✅ sem risco | §1 cria índice **NOVO** (`corridas_wear_dedup_idx`), **não toca** o índice do Apple. §2 só mexe em `watch_sync_log` (tabela que o celular nunca escreve). |
| Unique em `(user_id, timestamp)` | ✅ não existe | `corridas_user_timestamp_unique` é **dropada** de propósito (`corridas_schema.sql:47`): a mesma corrida pode vir de vários provedores com o mesmo horário. |

**Resumo:** a migração só adiciona um índice parcial restrito a `device IN ('wear_os',
'wear_os_standalone')` e ajusta uma constraint de uma tabela watch-only. Nenhuma coluna,
constraint ou índice usado pelo save do celular é alterado. O pré-requisito (`watch_migration.sql`
do Apple, que cria `data_inicio`/`watch_sync_log`) é checado por guarda — a migração falha cedo
e clara se faltar, sem deixar a base num estado intermediário.

---

## Passo 1 — Migração SQL

Aplica `samsung/supabase/wear_migration.sql` (idempotente; pode rodar mais de uma vez).
Pré-requisito: `apple/supabase/watch_migration.sql` já aplicado (a migração falha cedo e
claro se `corridas.data_inicio` não existir).

**Opção A — Dashboard (sem instalar nada):**
1. Supabase → projeto `dxfgmzaxplarrwcmbotp` → **SQL Editor** → New query.
2. Colar o conteúdo de `samsung/supabase/wear_migration.sql` e **Run**.
3. Conferir a saída do bloco de verificação (passo 4 do SQL).

**Opção B — CLI / psql:**
```bash
# via psql (precisa da connection string do projeto)
psql "$SUPABASE_DB_URL" -f samsung/supabase/wear_migration.sql

# ou via Supabase CLI linkado ao projeto
supabase db execute --file samsung/supabase/wear_migration.sql
```

---

## Passo 2 — Redeploy da edge function

Requer **Supabase CLI + Docker** (não dá para fazer pela Management API sem empacotar o
bundle). Mantém o **Verify-JWT ligado** (a função autentica pelo header do usuário).

A função vive em `apple/supabase/functions/watch-workout-save/`. Como o caminho relativo a
`apple/` já é `supabase/functions/...`, dá para deployar de lá sem copiar:

```bash
cd apple
supabase functions deploy watch-workout-save --project-ref dxfgmzaxplarrwcmbotp
```

**Recomendado (consistência do pipeline):** copiar a função para o diretório canônico de
deploy do app, para que futuros `supabase functions deploy` a incluam:
```bash
cp -r apple/supabase/functions/watch-workout-save \
      ../temporun-app/supabase/functions/watch-workout-save
cd ../temporun-app && supabase functions deploy watch-workout-save
```

---

## Passo 3 — Verificação

```bash
# 1. Endpoint responde (401 = live + gated; 404 = não deployada)
curl -s -o /dev/null -w "%{http_code}\n" -X POST \
  https://dxfgmzaxplarrwcmbotp.supabase.co/functions/v1/watch-workout-save -d '{}'

# 2. No SQL Editor — índice e constraint atualizados:
SELECT indexdef FROM pg_indexes WHERE indexname = 'corridas_watch_dedup_idx';
SELECT pg_get_constraintdef(oid) FROM pg_constraint
  WHERE conrelid = 'public.watch_sync_log'::regclass AND contype = 'c';
-- esperado: índice cobre wear_os/wear_os_standalone; CHECK inclui 'datalayer'.
```

Um teste end-to-end real só é possível com uma corrida vinda do relógio (Fase 2) ou um POST
autenticado com um JWT de usuário de teste e um payload mínimo no contrato (`WEAR_OS_PLAN.md`
§1.3) com `source = "wear_os_standalone"`.
