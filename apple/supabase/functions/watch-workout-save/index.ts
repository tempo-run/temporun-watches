// Supabase Edge Function: watch-workout-save
// Recebe corrida do Watch, calcula XP, atualiza streak e recordes pessoais atomicamente
// Endpoint: POST /functions/v1/watch-workout-save

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
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
  source: string              // "apple_watch" | "apple_watch_standalone"
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

function calcularXP(payload: WatchWorkoutPayload): number {
  // Base: 10 XP por km
  let xp = Math.floor(payload.distancia_km * 10)

  // Bônus por intensidade (zonas de FC)
  const totalSeg = payload.duracao_seg || 1
  const pctZ4 = payload.tempo_zona4 / totalSeg
  const pctZ5 = payload.tempo_zona5 / totalSeg

  if (pctZ4 > 0.20) xp += Math.floor(xp * 0.15)  // +15% se >20% em Z4
  if (pctZ5 > 0.10) xp += Math.floor(xp * 0.20)  // +20% se >10% em Z5

  // Bônus por tipo de treino
  const tipo = payload.treino_tipo ?? ""
  if (["Intervalado", "Tempo Run", "Subidas"].includes(tipo)) xp += 20
  else if (["Fartlek", "Strides"].includes(tipo))             xp += 10
  else if (["Longão Lento", "Longão com Ritmo", "Longão Progressivo"].includes(tipo)) xp += 15

  // Bônus por elevação (1 XP por 10m de ganho)
  xp += Math.floor(payload.ganho_elevacao / 10)

  // Bônus por longa distância
  if (payload.distancia_km >= 42)      xp += 100
  else if (payload.distancia_km >= 21) xp += 50
  else if (payload.distancia_km >= 10) xp += 20

  // Bônus de potência (Running Power > 250W)
  if (payload.running_power > 250)     xp += 10

  return Math.max(xp, 1)
}

// ─── Verificação de recordes pessoais ─────────────────────────────────────────

const DISTANCIAS_PR = [
  { label: "1km",   min: 0.9,  max: 1.1  },
  { label: "5km",   min: 4.8,  max: 5.2  },
  { label: "10km",  min: 9.8,  max: 10.2 },
  { label: "21km",  min: 20.8, max: 21.4 },
  { label: "42km",  min: 41.8, max: 42.6 },
]

async function verificarRecordes(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  payload: WatchWorkoutPayload
): Promise<PersonalRecord[]> {
  const novos: PersonalRecord[] = []

  for (const dist of DISTANCIAS_PR) {
    if (payload.distancia_km < dist.min || payload.distancia_km > dist.max) continue

    const { data: existente } = await supabase
      .from("recordes_pessoais")
      .select("tempo_seg, distancia_label")
      .eq("user_id", userId)
      .eq("distancia_label", dist.label)
      .single()

    const tempoNovo = payload.duracao_seg
    const tempoAnterior = existente?.tempo_seg ?? null

    if (tempoAnterior === null || tempoNovo < tempoAnterior) {
      await supabase
        .from("recordes_pessoais")
        .upsert({
          user_id:         userId,
          distancia_label: dist.label,
          tempo_seg:       tempoNovo,
          pace_medio:      payload.pace_medio,
          data_corrida:    payload.data_inicio,
          source:          payload.source,
        }, { onConflict: "user_id,distancia_label" })

      novos.push({
        distancia:      dist.label,
        tempo_anterior: tempoAnterior,
        tempo_novo:     tempoNovo,
      })
    }
  }

  return novos
}

// ─── Streak ───────────────────────────────────────────────────────────────────

async function atualizarStreak(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  dataFim: string
): Promise<number> {
  const hoje = new Date(dataFim).toISOString().split("T")[0]

  // Busca valores atuais do streak
  const { data: rows } = await supabase
    .from("user_data")
    .select("key, value")
    .eq("user_id", userId)
    .in("key", ["streak_atual", "streak_ultima_data", "streak_maximo"])

  const vals: Record<string, string> = {}
  for (const row of rows ?? []) vals[row.key] = row.value

  const streakAtual   = parseInt(vals["streak_atual"]   ?? "0")
  const streakMax     = parseInt(vals["streak_maximo"]  ?? "0")
  const ultimaData    = vals["streak_ultima_data"] ?? ""

  // Calcula diferença em dias
  const diffDias = ultimaData
    ? Math.floor((new Date(hoje).getTime() - new Date(ultimaData).getTime()) / 86400000)
    : 999

  let novoStreak: number
  if (diffDias === 0)      novoStreak = streakAtual          // mesma data, não incrementa
  else if (diffDias === 1) novoStreak = streakAtual + 1      // dia seguinte
  else                     novoStreak = 1                    // quebrou o streak

  const novoMax = Math.max(novoStreak, streakMax)

  // Upsert dos três valores
  await supabase.from("user_data").upsert([
    { user_id: userId, key: "streak_atual",       value: String(novoStreak) },
    { user_id: userId, key: "streak_ultima_data", value: hoje },
    { user_id: userId, key: "streak_maximo",      value: String(novoMax) },
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

serve(async (req: Request) => {
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
      sync_mode:    payload.source.includes("standalone") ? "standalone" : "watchconnectivity",
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
