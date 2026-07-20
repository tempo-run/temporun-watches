-- Índice único para deduplicação ATÔMICA de corridas do relógio.
--
-- Problema: a edge function watch-workout-save deduplica com "SELECT ±30s → INSERT",
-- que é check-then-insert e NÃO segura duas gravações concorrentes da mesma corrida
-- (retry do relógio + relay do iPhone) — as duas passam pelo SELECT antes de qualquer
-- commit e inserem 2 linhas.
--
-- Solução: um índice único em (user_id, data_inicio). A mesma corrida sempre carrega
-- o MESMO data_inicio (derivado do startDate do payload), então o índice colide e o
-- Postgres rejeita a segunda com erro 23505 — que a função passa a tratar como
-- duplicata (is_duplicate=true), em vez de criar linha dupla.
--
-- Parcial (WHERE data_inicio IS NOT NULL): as linhas antigas 'local'/'strava' têm
-- data_inicio NULL e ficam FORA do índice — nada nelas é afetado.

-- Pré-checagem: se JÁ existirem duplicatas (mesmo user_id + data_inicio) o CREATE
-- falha. Rode isto antes para listá-las e remova/mescle manualmente se aparecer algo:
--
--   select user_id, data_inicio, count(*), array_agg(id)
--   from corridas
--   where data_inicio is not null
--   group by user_id, data_inicio
--   having count(*) > 1;

create unique index if not exists corridas_user_data_inicio_uniq
  on public.corridas (user_id, data_inicio)
  where data_inicio is not null;
