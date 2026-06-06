-- =============================================================================
-- Triggers e funções server-side para o Watch App
-- Garante XP, streak e recordes corretos mesmo no modo standalone
-- (quando o Watch insere direto via REST sem passar pela edge function)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. FUNÇÃO: calcular XP de uma corrida
-- Fórmula exata do TempoRun.jsx (~linha 14049):
--   Math.round(km * 45 + seg / 60 * 2)
--   45 XP por km + 2 XP por minuto — flat, sem bônus por tipo ou intensidade
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION calcular_xp_corrida(corrida corridas)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN ROUND(corrida.distancia_km * 45 + corrida.duracao_seg / 60.0 * 2)::integer;
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. TRIGGER: preencher xp_ganho automaticamente ao inserir corrida
-- Ativa apenas quando xp_ganho não foi enviado (modo standalone / HealthKit import)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trg_fill_xp_ganho()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.xp_ganho IS NULL OR NEW.xp_ganho = 0 THEN
    NEW.xp_ganho := calcular_xp_corrida(NEW);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_corridas_xp ON corridas;
CREATE TRIGGER trg_corridas_xp
  BEFORE INSERT ON corridas
  FOR EACH ROW EXECUTE FUNCTION trg_fill_xp_ganho();

-- -----------------------------------------------------------------------------
-- 3. TRIGGER: acumular XP em user_data após inserção de corrida
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trg_acumular_xp()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  xp_atual integer;
BEGIN
  SELECT COALESCE(value::integer, 0) INTO xp_atual
  FROM user_data
  WHERE user_id = NEW.user_id AND key = 'xp_total';

  INSERT INTO user_data (user_id, key, value)
  VALUES (NEW.user_id, 'xp_total', (xp_atual + NEW.xp_ganho)::text)
  ON CONFLICT (user_id, key)
  DO UPDATE SET value = (xp_atual + NEW.xp_ganho)::text;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_corridas_acumular_xp ON corridas;
CREATE TRIGGER trg_corridas_acumular_xp
  AFTER INSERT ON corridas
  FOR EACH ROW
  WHEN (NEW.xp_ganho > 0)
  EXECUTE FUNCTION trg_acumular_xp();

-- -----------------------------------------------------------------------------
-- 4. TRIGGER: atualizar streak após inserção de corrida
-- Espelha calcStreak() do TempoRun.jsx (~linha 14394):
-- Conta SEMANAS ÚNICAS com pelo menos uma corrida (não dias consecutivos).
-- Semana = domingo da semana (date_trunc('week', ...) no PostgreSQL usa segunda —
-- usamos EXTRACT(DOW) para recuar ao domingo manualmente.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trg_atualizar_streak()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_novo_streak  integer;
  v_streak_max   integer;
BEGIN
  -- Conta semanas únicas com corrida para este usuário
  -- (inclui a corrida que acabou de ser inserida)
  SELECT COUNT(DISTINCT
    (timestamp::date - EXTRACT(DOW FROM timestamp::date)::integer)
  )
  INTO v_novo_streak
  FROM corridas
  WHERE user_id = NEW.user_id;

  -- Lê streak máximo atual
  SELECT COALESCE(value::integer, 0) INTO v_streak_max
  FROM user_data
  WHERE user_id = NEW.user_id AND key = 'streak_maximo';

  v_streak_max := GREATEST(v_novo_streak, COALESCE(v_streak_max, 0));

  INSERT INTO user_data (user_id, key, value) VALUES
    (NEW.user_id, 'streak_atual',  v_novo_streak::text),
    (NEW.user_id, 'streak_maximo', v_streak_max::text)
  ON CONFLICT (user_id, key)
  DO UPDATE SET value = EXCLUDED.value;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_corridas_streak ON corridas;
CREATE TRIGGER trg_corridas_streak
  AFTER INSERT ON corridas
  FOR EACH ROW EXECUTE FUNCTION trg_atualizar_streak();

-- -----------------------------------------------------------------------------
-- 5. TRIGGER: verificar e atualizar recordes pessoais
-- Espelha RP_TRACKED_DISTANCES + rpAttemptFromRun do TempoRun.jsx (~linha 3933)
-- 12 distâncias rastreadas; elegível para qualquer distância que a corrida COBRE.
-- Tempo interpolado proporcionalmente: ROUND(duracao_seg * (dist_km / distancia_km))
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trg_verificar_recordes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  dist            RECORD;
  tempo_interpolado integer;
  tempo_existente   integer;
  pace_seg          numeric;

  -- 12 distâncias rastreadas (label, km)
  distancias CONSTANT text[][] := ARRAY[
    ARRAY['400m',  '0.4'   ],
    ARRAY['800m',  '0.8'   ],
    ARRAY['1K',    '1.0'   ],
    ARRAY['1.6K',  '1.609' ],
    ARRAY['3.2K',  '3.219' ],
    ARRAY['5K',    '5.0'   ],
    ARRAY['10K',   '10.0'  ],
    ARRAY['15K',   '15.0'  ],
    ARRAY['10MI',  '16.093'],
    ARRAY['21K',   '21.097'],
    ARRAY['42K',   '42.195'],
    ARRAY['50K',   '50.0'  ]
  ];
  i integer;
  dist_label text;
  dist_km    numeric;
BEGIN
  FOR i IN 1..array_length(distancias, 1) LOOP
    dist_label := distancias[i][1];
    dist_km    := distancias[i][2]::numeric;

    -- Corrida cobre essa distância?
    IF NEW.distancia_km < dist_km - 0.01 THEN CONTINUE; END IF;

    -- Interpola o tempo proporcionalmente
    tempo_interpolado := GREATEST(1, ROUND(NEW.duracao_seg * (dist_km / NEW.distancia_km))::integer);

    -- Busca recorde existente
    SELECT tempo_seg INTO tempo_existente
    FROM recordes_pessoais
    WHERE user_id = NEW.user_id AND distancia = dist_label;

    -- Atualiza apenas se for melhor (menor tempo) ou novo
    IF tempo_existente IS NULL OR tempo_interpolado < tempo_existente THEN
      -- pace em seg/km → "M:SS/km"
      pace_seg := tempo_interpolado / dist_km;

      INSERT INTO recordes_pessoais (
        user_id, distancia, tempo_seg, tempo_display, data_rp, corrida_id
      ) VALUES (
        NEW.user_id,
        dist_label,
        tempo_interpolado,
        TO_CHAR(FLOOR(pace_seg / 60)::integer, 'FM9999') || ':' ||
          TO_CHAR(ROUND(MOD(pace_seg, 60))::integer, 'FM00') || '/km',
        COALESCE(NEW.data_inicio::date, NEW.timestamp::date),
        NEW.id
      )
      ON CONFLICT (user_id, distancia)
      DO UPDATE SET
        tempo_seg     = EXCLUDED.tempo_seg,
        tempo_display = EXCLUDED.tempo_display,
        data_rp       = EXCLUDED.data_rp,
        corrida_id    = EXCLUDED.corrida_id;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_corridas_recordes ON corridas;
CREATE TRIGGER trg_corridas_recordes
  AFTER INSERT ON corridas
  FOR EACH ROW EXECUTE FUNCTION trg_verificar_recordes();

-- -----------------------------------------------------------------------------
-- 6. CONSTRAINT UNIQUE em user_data (necessária para os ON CONFLICT acima)
-- -----------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_data_user_key_unique'
  ) THEN
    ALTER TABLE user_data ADD CONSTRAINT user_data_user_key_unique
      UNIQUE (user_id, key);
  END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- 7. CONSTRAINT UNIQUE em recordes_pessoais
-- -----------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'recordes_pessoais_user_distancia_unique'
  ) THEN
    ALTER TABLE recordes_pessoais ADD CONSTRAINT recordes_pessoais_user_distancia_unique
      UNIQUE (user_id, distancia);
  END IF;
END;
$$;
