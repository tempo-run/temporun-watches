-- =============================================================================
-- Migração: suporte ao TempoRun Wear OS (device = 'wear_os' / 'wear_os_standalone')
-- Rodar APÓS apple/supabase/watch_migration.sql e ANTES do primeiro deploy do
-- patch da edge function watch-workout-save (que passa a gravar sync_mode='datalayer').
-- Ver WEAR_OS_PLAN.md §9 e samsung/DECISIONS.md (D2).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Dedup: estende o índice único parcial para cobrir os devices Wear OS.
-- (Mesma semântica do Apple: uma corrida por user+data_inicio por relógio.)
-- -----------------------------------------------------------------------------

DROP INDEX IF EXISTS corridas_watch_dedup_idx;
CREATE UNIQUE INDEX IF NOT EXISTS corridas_watch_dedup_idx
  ON corridas (user_id, data_inicio)
  WHERE device IN ('apple_watch', 'apple_watch_standalone',
                   'wear_os', 'wear_os_standalone');

-- -----------------------------------------------------------------------------
-- 2. watch_sync_log: permite o modo de sync do Wear OS ('datalayer').
-- O constraint original só aceitava watchconnectivity/standalone/healthkit;
-- a edge function passa a gravar 'datalayer' para corridas vindas do Wear via celular.
-- (Nome do constraint é o auto-gerado pelo Postgres para CHECK inline de coluna.)
-- -----------------------------------------------------------------------------

ALTER TABLE watch_sync_log
  DROP CONSTRAINT IF EXISTS watch_sync_log_sync_mode_check;

ALTER TABLE watch_sync_log
  ADD CONSTRAINT watch_sync_log_sync_mode_check
  CHECK (sync_mode IN ('watchconnectivity', 'standalone', 'healthkit', 'datalayer'));

-- -----------------------------------------------------------------------------
-- 3. Nota sobre merge_watch_corrida: a função já é genérica (lê device do payload),
-- nenhuma alteração necessária — o cliente Wear envia device='wear_os'/'wear_os_standalone'.
-- A menção a 'samsung_watch' nos comentários da migração do Apple está OBSOLETA:
-- o valor padronizado é 'wear_os' (cobre qualquer relógio Wear OS, não só Samsung).
-- -----------------------------------------------------------------------------
