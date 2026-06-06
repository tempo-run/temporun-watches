-- =============================================================================
-- Migração: suporte ao TempoRun Watch App
-- Adicionar após o schema existente de corridas
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. COLUNAS NOVAS NA TABELA corridas
-- (as existentes: distancia_km, duracao_seg, pace_medio, bpm_medio,
--  cadencia_media, forca_w, calorias, dplus, polyline, splits, source)
-- -----------------------------------------------------------------------------

ALTER TABLE corridas
  -- Pace
  ADD COLUMN IF NOT EXISTS pace_melhor       text,          -- "5:12/km" (melhor split)
  ADD COLUMN IF NOT EXISTS pace_medio_seg    numeric,       -- seg/km numérico (além do text pace_medio)

  -- Velocidade
  ADD COLUMN IF NOT EXISTS velocidade_media  numeric,       -- m/s

  -- FC detalhada (bpm_medio já existe como integer)
  ADD COLUMN IF NOT EXISTS fc_min            integer,       -- bpm mínimo
  ADD COLUMN IF NOT EXISTS fc_max            integer,       -- bpm máximo
  ADD COLUMN IF NOT EXISTS fc_repouso        numeric,       -- bpm (pré-treino, do histórico HK)

  -- Métricas de saúde
  ADD COLUMN IF NOT EXISTS hrv_sdnn          numeric,       -- ms (SDNN)
  ADD COLUMN IF NOT EXISTS spo2              numeric,       -- % saturação O₂
  ADD COLUMN IF NOT EXISTS frequencia_resp   numeric,       -- resp/min
  ADD COLUMN IF NOT EXISTS vo2_estimado      numeric,       -- ml/kg/min

  -- Biomecânica Running Dynamics
  ADD COLUMN IF NOT EXISTS stride_length     numeric,       -- m
  ADD COLUMN IF NOT EXISTS running_power     numeric,       -- W (forca_w existe mas é integer; mantém os dois por compat)
  ADD COLUMN IF NOT EXISTS ground_contact    numeric,       -- ms
  ADD COLUMN IF NOT EXISTS vertical_osc      numeric,       -- cm
  ADD COLUMN IF NOT EXISTS vertical_ratio    numeric,       -- % (oscilação/passada)
  ADD COLUMN IF NOT EXISTS physical_effort   numeric,       -- METs

  -- Energia detalhada (calorias já existe como total)
  ADD COLUMN IF NOT EXISTS calorias_ativas   numeric,       -- kcal ativas
  ADD COLUMN IF NOT EXISTS calorias_basais   numeric,       -- kcal basais

  -- Elevação detalhada (dplus já existe como ganho)
  ADD COLUMN IF NOT EXISTS elevacao_perda    integer,       -- m de descida acumulada
  ADD COLUMN IF NOT EXISTS altitude_max      numeric,       -- m (nível do mar)
  ADD COLUMN IF NOT EXISTS altitude_min      numeric,       -- m (nível do mar)

  -- Zonas de FC (segundos em cada zona)
  ADD COLUMN IF NOT EXISTS tempo_zona1       numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tempo_zona2       numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tempo_zona3       numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tempo_zona4       numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tempo_zona5       numeric DEFAULT 0,

  -- Metadados do Watch
  ADD COLUMN IF NOT EXISTS device            text,          -- 'apple_watch', 'samsung_watch', 'iphone', etc.
  ADD COLUMN IF NOT EXISTS watch_os_version  text,          -- ex: "10.2"
  ADD COLUMN IF NOT EXISTS data_inicio       timestamptz,   -- início exato da sessão HK
  ADD COLUMN IF NOT EXISTS data_fim          timestamptz;   -- fim exato da sessão HK

-- Atualiza source values existentes para padronizar
-- (o Watch envia: 'apple_watch_standalone' ou 'apple_watch')
-- Nenhum UPDATE necessário — source já é text livre

-- -----------------------------------------------------------------------------
-- 2. ÍNDICE para consultas por device (Watch busca próprias corridas)
-- -----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS corridas_device_idx
  ON corridas (user_id, device, timestamp DESC);

-- -----------------------------------------------------------------------------
-- 3. FUNÇÃO para evitar duplicatas do Watch
-- (o Watch pode tentar inserir a mesma corrida pelo Caminho A via HealthKit
--  E pelo Caminho B via WatchConnectivity — prevenir duplicate)
-- -----------------------------------------------------------------------------

CREATE UNIQUE INDEX IF NOT EXISTS corridas_watch_dedup_idx
  ON corridas (user_id, data_inicio)
  WHERE device IN ('apple_watch', 'apple_watch_standalone');

-- Garante que, se o Watch tentar inserir a mesma corrida duas vezes
-- (ex: HealthKit import + WC), a segunda tentativa seja ignorada.
-- No cliente Swift: usar `Prefer: resolution=ignore-duplicates`

-- -----------------------------------------------------------------------------
-- 4. RLS — política para o Watch inserir diretamente (modo standalone)
-- (O Watch usa o mesmo JWT do usuário, então a política padrão já cobre.
--  Esta política é explícita para clareza e auditoria.)
-- -----------------------------------------------------------------------------

-- Política existente cobre INSERT autenticado. Verificar se existe:
-- SELECT * FROM pg_policies WHERE tablename = 'corridas';
--
-- Se não existir política de INSERT, criar:
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'corridas'
      AND policyname = 'Usuário insere próprias corridas'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "Usuário insere próprias corridas"
        ON corridas FOR INSERT
        WITH CHECK (auth.uid() = user_id);
    $policy$;
  END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- 5. TABELA: watch_sync_log (opcional — rastrear tentativas standalone)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS watch_sync_log (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid REFERENCES auth.users ON DELETE CASCADE,
  corrida_id    uuid REFERENCES corridas ON DELETE SET NULL,
  device        text NOT NULL,
  sync_mode     text NOT NULL CHECK (sync_mode IN ('watchconnectivity', 'standalone', 'healthkit')),
  status        text NOT NULL CHECK (status IN ('success', 'queued', 'failed')),
  attempts      integer DEFAULT 1,
  error_msg     text,
  payload_size  integer,           -- bytes do payload JSON
  synced_at     timestamptz DEFAULT now()
);

ALTER TABLE watch_sync_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Usuário vê próprios logs" ON watch_sync_log;
CREATE POLICY "Usuário vê próprios logs"
  ON watch_sync_log FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Usuário insere próprios logs" ON watch_sync_log;
CREATE POLICY "Usuário insere próprios logs"
  ON watch_sync_log FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS watch_sync_log_user_idx
  ON watch_sync_log (user_id, synced_at DESC);

-- -----------------------------------------------------------------------------
-- 6. FUNÇÃO: merge de corrida duplicada Watch + HealthKit import
-- Quando o Watch grava no HealthKit (Caminho A) E depois envia via WC (Caminho B),
-- podem existir duas linhas para a mesma sessão. Esta função mescla os dados.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION merge_watch_corrida(
  p_user_id      uuid,
  p_data_inicio  timestamptz,
  p_payload      jsonb
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_existing_id uuid;
BEGIN
  -- Busca corrida existente com mesmo user + início (±30s de tolerância)
  SELECT id INTO v_existing_id
  FROM corridas
  WHERE user_id = p_user_id
    AND ABS(EXTRACT(EPOCH FROM (timestamp - p_data_inicio))) < 30
  ORDER BY created_at
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    -- Enriquece com os dados do Watch (não sobrescreve campos já preenchidos com valor)
    UPDATE corridas SET
      fc_min          = COALESCE(fc_min,          (p_payload->>'fc_min')::integer),
      fc_max          = COALESCE(fc_max,          (p_payload->>'fc_max')::integer),
      hrv_sdnn        = COALESCE(hrv_sdnn,        (p_payload->>'hrv_sdnn')::numeric),
      spo2            = COALESCE(spo2,            (p_payload->>'spo2')::numeric),
      frequencia_resp = COALESCE(frequencia_resp, (p_payload->>'frequencia_resp')::numeric),
      vo2_estimado    = COALESCE(vo2_estimado,    (p_payload->>'vo2_estimado')::numeric),
      stride_length   = COALESCE(stride_length,   (p_payload->>'stride_length')::numeric),
      running_power   = COALESCE(running_power,   (p_payload->>'running_power')::numeric),
      ground_contact  = COALESCE(ground_contact,  (p_payload->>'ground_contact')::numeric),
      vertical_osc    = COALESCE(vertical_osc,    (p_payload->>'vertical_osc')::numeric),
      vertical_ratio  = COALESCE(vertical_ratio,  (p_payload->>'vertical_ratio')::numeric),
      physical_effort = COALESCE(physical_effort, (p_payload->>'physical_effort')::numeric),
      calorias_ativas = COALESCE(calorias_ativas, (p_payload->>'calorias_ativas')::numeric),
      calorias_basais = COALESCE(calorias_basais, (p_payload->>'calorias_basais')::numeric),
      elevacao_perda  = COALESCE(elevacao_perda,  (p_payload->>'elevacao_perda')::integer),
      altitude_max    = COALESCE(altitude_max,    (p_payload->>'altitude_max')::numeric),
      altitude_min    = COALESCE(altitude_min,    (p_payload->>'altitude_min')::numeric),
      tempo_zona1     = COALESCE(tempo_zona1,     (p_payload->>'tempo_zona1')::numeric),
      tempo_zona2     = COALESCE(tempo_zona2,     (p_payload->>'tempo_zona2')::numeric),
      tempo_zona3     = COALESCE(tempo_zona3,     (p_payload->>'tempo_zona3')::numeric),
      tempo_zona4     = COALESCE(tempo_zona4,     (p_payload->>'tempo_zona4')::numeric),
      tempo_zona5     = COALESCE(tempo_zona5,     (p_payload->>'tempo_zona5')::numeric),
      device          = COALESCE(device, p_payload->>'device'),
      data_inicio     = COALESCE(data_inicio,     (p_payload->>'data_inicio')::timestamptz),
      data_fim        = COALESCE(data_fim,        (p_payload->>'data_fim')::timestamptz)
    WHERE id = v_existing_id;

    RETURN v_existing_id;
  ELSE
    -- Nenhuma corrida existente: insere normalmente
    INSERT INTO corridas (
      user_id, source, distancia_km, duracao_seg, pace_medio,
      bpm_medio, cadencia_media, forca_w, calorias, dplus,
      splits, fc_min, fc_max, fc_repouso, hrv_sdnn, spo2,
      frequencia_resp, vo2_estimado, stride_length, running_power,
      ground_contact, vertical_osc, vertical_ratio, physical_effort,
      calorias_ativas, calorias_basais, elevacao_perda,
      altitude_max, altitude_min,
      tempo_zona1, tempo_zona2, tempo_zona3, tempo_zona4, tempo_zona5,
      device, data_inicio, data_fim, timestamp
    ) VALUES (
      p_user_id,
      p_payload->>'source',
      (p_payload->>'distancia_km')::numeric,
      (p_payload->>'duracao_seg')::integer,
      p_payload->>'pace_medio',
      (p_payload->>'bpm_medio')::integer,
      (p_payload->>'cadencia_media')::integer,
      (p_payload->>'forca_w')::integer,
      (p_payload->>'calorias')::integer,
      (p_payload->>'dplus')::integer,
      (p_payload->'splits'),
      (p_payload->>'fc_min')::integer,
      (p_payload->>'fc_max')::integer,
      (p_payload->>'fc_repouso')::numeric,
      (p_payload->>'hrv_sdnn')::numeric,
      (p_payload->>'spo2')::numeric,
      (p_payload->>'frequencia_resp')::numeric,
      (p_payload->>'vo2_estimado')::numeric,
      (p_payload->>'stride_length')::numeric,
      (p_payload->>'running_power')::numeric,
      (p_payload->>'ground_contact')::numeric,
      (p_payload->>'vertical_osc')::numeric,
      (p_payload->>'vertical_ratio')::numeric,
      (p_payload->>'physical_effort')::numeric,
      (p_payload->>'calorias_ativas')::numeric,
      (p_payload->>'calorias_basais')::numeric,
      (p_payload->>'elevacao_perda')::integer,
      (p_payload->>'altitude_max')::numeric,
      (p_payload->>'altitude_min')::numeric,
      (p_payload->>'tempo_zona1')::numeric,
      (p_payload->>'tempo_zona2')::numeric,
      (p_payload->>'tempo_zona3')::numeric,
      (p_payload->>'tempo_zona4')::numeric,
      (p_payload->>'tempo_zona5')::numeric,
      p_payload->>'device',
      (p_payload->>'data_inicio')::timestamptz,
      (p_payload->>'data_fim')::timestamptz,
      COALESCE((p_payload->>'data_inicio')::timestamptz, now())
    )
    RETURNING id INTO v_existing_id;

    RETURN v_existing_id;
  END IF;
END;
$$;

-- Permissão para usuários autenticados chamarem a função
GRANT EXECUTE ON FUNCTION merge_watch_corrida TO authenticated;
