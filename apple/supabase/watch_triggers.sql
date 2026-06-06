-- =============================================================================
-- Triggers e funções server-side para o Watch App
-- Garante XP, streak e recordes corretos mesmo no modo standalone
-- (quando o Watch insere direto via REST sem passar pela edge function)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. FUNÇÃO: calcular XP de uma corrida
-- Espelha a lógica de calcularXP() da edge function watch-workout-save
-- Usada pela trigger abaixo e pode ser chamada manualmente
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION calcular_xp_corrida(corrida corridas)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  xp          integer;
  pct_z4      numeric;
  pct_z5      numeric;
BEGIN
  -- Base: 10 XP por km
  xp := GREATEST(FLOOR(corrida.distancia_km * 10), 1);

  -- Bônus por zonas de FC (se disponível)
  IF corrida.duracao_seg > 0 THEN
    pct_z4 := COALESCE(corrida.tempo_zona4, 0) / corrida.duracao_seg;
    pct_z5 := COALESCE(corrida.tempo_zona5, 0) / corrida.duracao_seg;

    IF pct_z4 > 0.20 THEN xp := xp + FLOOR(xp * 0.15); END IF;
    IF pct_z5 > 0.10 THEN xp := xp + FLOOR(xp * 0.20); END IF;
  END IF;

  -- Bônus por elevação (1 XP por 10m)
  xp := xp + FLOOR(COALESCE(corrida.dplus, 0) / 10);

  -- Bônus por distância
  IF    corrida.distancia_km >= 42 THEN xp := xp + 100;
  ELSIF corrida.distancia_km >= 21 THEN xp := xp + 50;
  ELSIF corrida.distancia_km >= 10 THEN xp := xp + 20;
  END IF;

  -- Bônus de potência
  IF COALESCE(corrida.running_power, 0) > 250 THEN xp := xp + 10; END IF;

  RETURN xp;
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
  -- Só calcula se não foi enviado pelo cliente (evita sobrescrever edge function)
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
  -- Lê XP atual
  SELECT COALESCE(value::integer, 0) INTO xp_atual
  FROM user_data
  WHERE user_id = NEW.user_id AND key = 'xp_total';

  -- Upsert com o novo total
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
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trg_atualizar_streak()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_hoje          date;
  v_ultima_data   date;
  v_streak_atual  integer;
  v_streak_max    integer;
  v_diff_dias     integer;
  v_novo_streak   integer;
BEGIN
  v_hoje := (NEW.data_fim::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date;

  -- Lê estado atual do streak
  SELECT
    MAX(CASE WHEN key = 'streak_atual'       THEN value::integer END),
    MAX(CASE WHEN key = 'streak_maximo'      THEN value::integer END),
    MAX(CASE WHEN key = 'streak_ultima_data' THEN value::date    END)
  INTO v_streak_atual, v_streak_max, v_ultima_data
  FROM user_data
  WHERE user_id = NEW.user_id
    AND key IN ('streak_atual', 'streak_maximo', 'streak_ultima_data');

  v_streak_atual := COALESCE(v_streak_atual, 0);
  v_streak_max   := COALESCE(v_streak_max,   0);

  -- Calcula diferença em dias
  IF v_ultima_data IS NULL THEN
    v_diff_dias := 999;
  ELSE
    v_diff_dias := v_hoje - v_ultima_data;
  END IF;

  -- Lógica de streak
  IF    v_diff_dias = 0 THEN v_novo_streak := v_streak_atual;      -- mesma data
  ELSIF v_diff_dias = 1 THEN v_novo_streak := v_streak_atual + 1;  -- consecutivo
  ELSE                       v_novo_streak := 1;                   -- quebrou
  END IF;

  v_streak_max := GREATEST(v_novo_streak, v_streak_max);

  -- Upsert dos três valores
  INSERT INTO user_data (user_id, key, value) VALUES
    (NEW.user_id, 'streak_atual',       v_novo_streak::text),
    (NEW.user_id, 'streak_ultima_data', v_hoje::text),
    (NEW.user_id, 'streak_maximo',      v_streak_max::text)
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
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trg_verificar_recordes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_distancia_label text;
  v_tempo_atual     integer;
BEGIN
  -- Determina a faixa de distância
  v_distancia_label := CASE
    WHEN NEW.distancia_km BETWEEN 0.9  AND 1.1  THEN '1km'
    WHEN NEW.distancia_km BETWEEN 4.8  AND 5.2  THEN '5km'
    WHEN NEW.distancia_km BETWEEN 9.8  AND 10.2 THEN '10km'
    WHEN NEW.distancia_km BETWEEN 20.8 AND 21.4 THEN '21km'
    WHEN NEW.distancia_km BETWEEN 41.8 AND 42.6 THEN '42km'
    ELSE NULL
  END;

  -- Sem distância de referência, ignora
  IF v_distancia_label IS NULL THEN RETURN NEW; END IF;

  -- Busca recorde existente
  SELECT tempo_seg INTO v_tempo_atual
  FROM recordes_pessoais
  WHERE user_id = NEW.user_id
    AND distancia_label = v_distancia_label;

  -- Atualiza apenas se for melhor (menor tempo) ou novo
  IF v_tempo_atual IS NULL OR NEW.duracao_seg < v_tempo_atual THEN
    INSERT INTO recordes_pessoais (
      user_id, distancia_label, tempo_seg, pace_medio, data_corrida, source
    ) VALUES (
      NEW.user_id,
      v_distancia_label,
      NEW.duracao_seg,
      NEW.pace_medio,
      COALESCE(NEW.data_inicio, NEW.timestamp),
      NEW.source
    )
    ON CONFLICT (user_id, distancia_label)
    DO UPDATE SET
      tempo_seg    = EXCLUDED.tempo_seg,
      pace_medio   = EXCLUDED.pace_medio,
      data_corrida = EXCLUDED.data_corrida,
      source       = EXCLUDED.source;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_corridas_recordes ON corridas;
CREATE TRIGGER trg_corridas_recordes
  AFTER INSERT ON corridas
  FOR EACH ROW EXECUTE FUNCTION trg_verificar_recordes();

-- -----------------------------------------------------------------------------
-- 6. CONSTRAINT UNIQUE em user_data (necessária para os ON CONFLICT acima)
-- Verifica se já existe; se não, cria
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
      UNIQUE (user_id, distancia_label);
  END IF;
END;
$$;
