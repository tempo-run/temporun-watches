// Supabase Edge Function: watch-workout-save
// Recebe corrida do Watch, calcula XP, atualiza streak e recordes pessoais atomicamente
// Endpoint: POST /functions/v1/watch-workout-save

import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// ─── Tipos ────────────────────────────────────────────────────────────────────

interface WatchWorkoutPayload {
  // Corrida
  distancia_km: number
  duracao_seg: number
  pace_medio: number          // seg/km
  pace_melhor: number
  velocidade_media: number    // m/s
  step_count: number
  cadencia: number
  // Biomecânica
  stride_length: number
  running_power: number
  ground_contact: number
  vertical_osc: number
  vertical_ratio: number
  physical_effort: number
  // Cardio
  bpm_medio: number
  fc_min: number
  fc_max: number
  fc_repouso: number
  hrv_sdnn: number
  spo2: number
  frequencia_resp: number
  vo2_estimado: number
  // Zonas
  tempo_zona1: number
  tempo_zona2: number
  tempo_zona3: number
  tempo_zona4: number
  tempo_zona5: number
  // Energia
  calorias_ativas: number
  calorias_basais: number
  calorias_total: number
  // Altitude
  ganho_elevacao: number
  perda_elevacao: number
  altitude_max: number
  altitude_min: number
  // Splits
  splits: SplitPayload[]
  // Metadados
  data_inicio: string         // ISO8601
  data_fim: string
  source: string              // "apple_watch" | "apple_watch_standalone" | "wear_os" | "wear_os_standalone"
  // Opcional: vínculo com plano de treino
  plano_id?: string
  plano_semana?: number
  treino_tipo?: string        // "Tempo Run", "Rodagem Leve", etc.
}

interface SplitPayload {
  km: number
  duracao: number
  pace: number
  fc_media: number
  ganho_elevacao: number
}

interface SaveResult {
  corrida_id: string
  xp_ganho: number
  streak_atual: number
  novos_recordes: PersonalRecord[]
  is_duplicate: boolean
}

interface PersonalRecord {
  distancia: string
  tempo_anterior: number | null
  tempo_novo: number
}

// ─── Cálculo de XP ────────────────────────────────────────────────────────────
// Fórmula exata do TempoRun.jsx (~linha 14049):
//   Math.round(km * 45 + seg / 60 * 2)
//   45 XP por km + 2 XP por minuto — flat, sem bônus por tipo ou intensidade

function calcularXP(payload: WatchWorkoutPayload): number {
  return Math.round(payload.distancia_km * 45 + payload.duracao_seg / 60 * 2)
}

// ─── Verificação de recordes pessoais ─────────────────────────────────────────
// Espelha RP_TRACKED_DISTANCES + rpAttemptFromRun do TempoRun.jsx (~linha 3933)
// Interpolação proporcional: rpSeg = round(duracao_seg * (dist.km / km_corrida))
// Corrida elegível para qualquer distância que ela COBRE (km_corrida >= dist.km)

const RP_TRACKED_DISTANCES = [
  { label: "400m",  key: "400m", km: 0.4    },
  { label: "800m",  key: "800m", km: 0.8    },
  { label: "1K",    key: "1K",   km: 1.0    },
  { label: "1.6K",  key: "1.6K", km: 1.609  },
  { label: "3.2K",  key: "3.2K", km: 3.219  },
  { label: "5K",    key: "5K",   km: 5.0    },
  { label: "10K",   key: "10K",  km: 10.0   },
  { label: "15K",   key: "15K",  km: 15.0   },
  { label: "10MI",  key: "10MI", km: 16.093 },
  { label: "21K",   key: "21K",  km: 21.097 },
  { label: "42K",   key: "42K",  km: 42.195 },
  { label: "50K",   key: "50K",  km: 50.0   },
]

async function verificarRecordes(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  payload: WatchWorkoutPayload
): Promise<PersonalRecord[]> {
  const novos: PersonalRecord[] = []

  for (const dist of RP_TRACKED_DISTANCES) {
    // Corrida cobre essa distância?
    if (payload.distancia_km < dist.km - 0.01) continue

    // Interpola o tempo proporcionalmente (mesma lógica do rpAttemptFromRun)
    const tempoInterpolado = Math.max(1, Math.round(
      payload.duracao_seg * (dist.km / payload.distancia_km)
    ))

    const { data: existente } = await supabase
      .from("recordes_pessoais")
      .select("tempo_seg")
      .eq("user_id", userId)
      .eq("distancia_label", dist.key)
      .single()

    const tempoAnterior = existente?.tempo_seg ?? null

    if (tempoAnterior === null || tempoInterpolado < tempoAnterior) {
      await supabase
        .from("recordes_pessoais")
        .upsert({
          user_id:         userId,
          distancia_label: dist.key,
          tempo_seg:       tempoInterpolado,
          pace_medio:      formatPace(tempoInterpolado / dist.km),
          data_corrida:    payload.data_inicio,
          source:          payload.source,
        }, { onConflict: "user_id,distancia_label" })

      novos.push({
        distancia:      dist.label,
        tempo_anterior: tempoAnterior,
        tempo_novo:     tempoInterpolado,
      })
    }
  }

  return novos
}

// ─── Streak ───────────────────────────────────────────────────────────────────
// Espelha calcStreak() do TempoRun.jsx (~linha 14394):
// Conta SEMANAS ÚNICAS com pelo menos uma corrida (não dias consecutivos).
// Semana = domingo da semana do timestamp.

function domingoSemana(date: Date): string {
  const d = new Date(date)
  d.setDate(d.getDate() - d.getDay())   // recua para o domingo
  d.setHours(0, 0, 0, 0)
  return d.toISOString().split("T")[0]
}

async function atualizarStreak(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  dataFim: string
): Promise<number> {
  // Busca todas as corridas do usuário para contar semanas únicas
  const { data: corridas } = await supabase
    .from("corridas")
    .select("timestamp")
    .eq("user_id", userId)
    .order("timestamp", { ascending: false })

  // Semanas únicas com corrida
  const semanasUnicas = new Set(
    (corridas ?? []).map(r => domingoSemana(new Date(r.timestamp)))
  )
  const novoStreak = semanasUnicas.size

  // Persiste em user_data para as complicações e o app lerem
  const { data: rows } = await supabase
    .from("user_data")
    .select("key, value")
    .eq("user_id", userId)
    .in("key", ["streak_maximo"])

  const streakMax = Math.max(
    novoStreak,
    parseInt(rows?.find(r => r.key === "streak_maximo")?.value ?? "0")
  )

  await supabase.from("user_data").upsert([
    { user_id: userId, key: "streak_atual",  value: String(novoStreak) },
    { user_id: userId, key: "streak_maximo", value: String(streakMax)  },
  ], { onConflict: "user_id,key" })

  return novoStreak
}

// ─── XP acumulado ─────────────────────────────────────────────────────────────

async function acumularXP(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  xpGanho: number
): Promise<void> {
  const { data } = await supabase
    .from("user_data")
    .select("value")
    .eq("user_id", userId)
    .eq("key", "xp_total")
    .single()

  const xpAtual = parseInt(data?.value ?? "0")

  await supabase.from("user_data").upsert(
    { user_id: userId, key: "xp_total", value: String(xpAtual + xpGanho) },
    { onConflict: "user_id,key" }
  )
}

// ─── Handler principal ────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin":  "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    })
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    // Autentica o usuário via JWT do header
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) return errorResponse(401, "Authorization header obrigatório")

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", "")
    )
    if (authError || !user) return errorResponse(401, "Token inválido")

    const payload: WatchWorkoutPayload = await req.json()

    // 1. Deduplicação — busca corrida com mesmo início (±30s)
    const dataInicio = new Date(payload.data_inicio)
    const inicioMin  = new Date(dataInicio.getTime() - 30000).toISOString()
    const inicioMax  = new Date(dataInicio.getTime() + 30000).toISOString()

    const { data: existente } = await supabase
      .from("corridas")
      .select("id")
      .eq("user_id", user.id)
      .gte("data_inicio", inicioMin)
      .lte("data_inicio", inicioMax)
      .single()

    if (existente) {
      // Corrida duplicada — enriquece e retorna sem recalcular XP/streak
      await supabase.from("corridas").update({
        fc_min:          payload.fc_min,
        fc_max:          payload.fc_max,
        hrv_sdnn:        payload.hrv_sdnn,
        spo2:            payload.spo2,
        frequencia_resp: payload.frequencia_resp,
        vo2_estimado:    payload.vo2_estimado,
        stride_length:   payload.stride_length,
        running_power:   payload.running_power,
        ground_contact:  payload.ground_contact,
        vertical_osc:    payload.vertical_osc,
        vertical_ratio:  payload.vertical_ratio,
        physical_effort: payload.physical_effort,
        calorias_ativas: payload.calorias_ativas,
        calorias_basais: payload.calorias_basais,
        elevacao_perda:  payload.perda_elevacao,
        altitude_max:    payload.altitude_max,
        altitude_min:    payload.altitude_min,
        tempo_zona1:     payload.tempo_zona1,
        tempo_zona2:     payload.tempo_zona2,
        tempo_zona3:     payload.tempo_zona3,
        tempo_zona4:     payload.tempo_zona4,
        tempo_zona5:     payload.tempo_zona5,
        device:          payload.source,
      }).eq("id", existente.id)

      return jsonResponse({ corrida_id: existente.id, xp_ganho: 0, streak_atual: 0, novos_recordes: [], is_duplicate: true })
    }

    // 2. Calcula XP
    const xpGanho = calcularXP(payload)

    // 3. Insere corrida
    const { data: novaCorrida, error: insertError } = await supabase
      .from("corridas")
      .insert({
        user_id:         user.id,
        source:          payload.source,
        distancia_km:    payload.distancia_km,
        duracao_seg:     payload.duracao_seg,
        pace_medio:      formatPace(payload.pace_medio),
        pace_medio_seg:  payload.pace_medio,
        pace_melhor:     formatPace(payload.pace_melhor),
        velocidade_media: payload.velocidade_media,
        bpm_medio:       Math.round(payload.bpm_medio),
        cadencia_media:  Math.round(payload.cadencia),
        forca_w:         Math.round(payload.running_power),
        calorias:        Math.round(payload.calorias_total),
        calorias_ativas: payload.calorias_ativas,
        calorias_basais: payload.calorias_basais,
        dplus:           Math.round(payload.ganho_elevacao),
        elevacao_perda:  Math.round(payload.perda_elevacao),
        altitude_max:    payload.altitude_max,
        altitude_min:    payload.altitude_min,
        fc_min:          payload.fc_min,
        fc_max:          payload.fc_max,
        fc_repouso:      payload.fc_repouso,
        hrv_sdnn:        payload.hrv_sdnn,
        spo2:            payload.spo2,
        frequencia_resp: payload.frequencia_resp,
        vo2_estimado:    payload.vo2_estimado,
        stride_length:   payload.stride_length,
        running_power:   payload.running_power,
        ground_contact:  payload.ground_contact,
        vertical_osc:    payload.vertical_osc,
        vertical_ratio:  payload.vertical_ratio,
        physical_effort: payload.physical_effort,
        tempo_zona1:     payload.tempo_zona1,
        tempo_zona2:     payload.tempo_zona2,
        tempo_zona3:     payload.tempo_zona3,
        tempo_zona4:     payload.tempo_zona4,
        tempo_zona5:     payload.tempo_zona5,
        splits:          payload.splits,
        xp_ganho:        xpGanho,
        device:          payload.source,
        data_inicio:     payload.data_inicio,
        data_fim:        payload.data_fim,
        timestamp:       payload.data_inicio,
        // Vínculo com plano (se enviado)
        ...(payload.plano_id ? { plano_id: payload.plano_id } : {}),
      })
      .select("id")
      .single()

    if (insertError) return errorResponse(500, insertError.message)

    // 4. Streak, XP acumulado e recordes em paralelo
    const [streakAtual, novosRecordes] = await Promise.all([
      atualizarStreak(supabase, user.id, payload.data_fim),
      verificarRecordes(supabase, user.id, payload),
      acumularXP(supabase, user.id, xpGanho),
    ])

    // 5. Log de sync
    await supabase.from("watch_sync_log").insert({
      user_id:      user.id,
      corrida_id:   novaCorrida.id,
      device:       payload.source,
      sync_mode:    payload.source.includes("standalone") ? "standalone"
                  : payload.source.startsWith("wear") ? "datalayer"
                  : "watchconnectivity",
      status:       "success",
      payload_size: JSON.stringify(payload).length,
    })

    const result: SaveResult = {
      corrida_id:     novaCorrida.id,
      xp_ganho:       xpGanho,
      streak_atual:   streakAtual,
      novos_recordes: novosRecordes,
      is_duplicate:   false,
    }

    return jsonResponse(result)

  } catch (err) {
    return errorResponse(500, String(err))
  }
})

// ─── Helpers ─────────────────────────────────────────────────────────────────

function formatPace(seg: number): string {
  if (!seg || seg <= 0) return "--:--"
  const m = Math.floor(seg / 60)
  const s = Math.round(seg % 60)
  return `${m}:${s.toString().padStart(2, "0")}/km`
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
  })
}

function errorResponse(status: number, message: string): Response {
  return jsonResponse({ error: message }, status)
}
