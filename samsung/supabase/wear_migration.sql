-- =============================================================================
-- Migração: suporte ao TempoRun Wear OS (device = 'wear_os' / 'wear_os_standalone')
--
-- Idempotente e segura para rodar em PRODUÇÃO (pode rodar mais de uma vez).
-- PRÉ-REQUISITO: apple/supabase/watch_migration.sql já aplicado (cria a coluna
--   corridas.data_inicio, a tabela watch_sync_log e o índice de dedup do Apple).
-- ORDEM: rodar esta migração ANTES de redeployar a edge function watch-workout-save
--   com o patch do sync_mode (que passa a gravar 'datalayer'). Se a função for
--   deployada antes, o INSERT em watch_sync_log falha no CHECK e o log é perdido
--   (a corrida em si é salva — o log é best-effort).
-- Ver WEAR_OS_PLAN.md §9 e samsung/DECISIONS.md (D2).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. Guardas de pré-requisito — falha cedo e claro se a base não estiver pronta.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF to_regclass('public.corridas') IS NULL THEN
    RAISE EXCEPTION 'Tabela corridas inexistente — base do app não inicializada.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'corridas' AND column_name = 'data_inicio'
  ) THEN
    RAISE EXCEPTION 'corridas.data_inicio ausente — rode apple/supabase/watch_migration.sql primeiro.';
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 1. Dedup: estende o índice único parcial para cobrir os devices Wear OS.
--    (Mesma semântica do Apple: uma corrida por user+data_inicio por relógio.)
--    Seguro: não há linhas wear_os ainda, e o índice do Apple já garantia que
--    não há duplicatas apple_watch — então o CREATE não pode falhar por colisão.
--    O lock de escrita do CREATE INDEX é breve (tabela pequena); se a tabela for
--    grande, trocar por CREATE UNIQUE INDEX CONCURRENTLY (fora de transação).
-- -----------------------------------------------------------------------------
DROP INDEX IF EXISTS corridas_watch_dedup_idx;
CREATE UNIQUE INDEX IF NOT EXISTS corridas_watch_dedup_idx
  ON corridas (user_id, data_inicio)
  WHERE device IN ('apple_watch', 'apple_watch_standalone',
                   'wear_os', 'wear_os_standalone');

-- -----------------------------------------------------------------------------
-- 2. watch_sync_log: permite o modo de sync do Wear OS ('datalayer').
--    Remove de forma ROBUSTA qualquer CHECK que restrinja sync_mode (o nome
--    auto-gerado pode variar entre ambientes) e recria com o conjunto completo.
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  c record;
BEGIN
  IF to_regclass('public.watch_sync_log') IS NULL THEN
    RAISE NOTICE 'watch_sync_log inexistente — pulando (será criada por watch_migration.sql).';
    RETURN;
  END IF;

  -- Dropa todo CHECK constraint que mencione sync_mode (qualquer que seja o nome).
  FOR c IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.watch_sync_log'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%sync_mode%'
  LOOP
    EXECUTE format('ALTER TABLE public.watch_sync_log DROP CONSTRAINT %I', c.conname);
  END LOOP;

  ALTER TABLE public.watch_sync_log
    ADD CONSTRAINT watch_sync_log_sync_mode_check
    CHECK (sync_mode IN ('watchconnectivity', 'standalone', 'healthkit', 'datalayer'));
END $$;

-- -----------------------------------------------------------------------------
-- 3. Nota sobre merge_watch_corrida: a função NÃO está no caminho do Wear (a
--    edge function watch-workout-save faz o próprio insert/update). Ela lê chaves
--    no formato da TABELA (fc_min, ground_contact, ...), não do contrato do cliente.
--    Nenhuma alteração necessária aqui. A menção a 'samsung_watch' nos comentários
--    da migração do Apple está OBSOLETA: o valor padronizado é 'wear_os'.
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- 4. Verificação (rodar e conferir manualmente após aplicar):
--    SELECT indexdef FROM pg_indexes WHERE indexname = 'corridas_watch_dedup_idx';
--    SELECT pg_get_constraintdef(oid) FROM pg_constraint
--      WHERE conrelid = 'public.watch_sync_log'::regclass AND contype = 'c';
-- -----------------------------------------------------------------------------
