import Foundation

// MARK: - Tipos de treino (espelha os 12 tipos permitidos pelo SYS_PLAN_WEEK)

enum WorkoutType: String, Codable {
    // Rodagem
    case rodagemLeve       = "Rodagem Leve"
    case rodagemModerada   = "Rodagem Moderada"
    case rodagemProgressiva = "Rodagem Progressiva"
    // Longão
    case longaoLento       = "Longão Lento"
    case longaoComRitmo    = "Longão com Ritmo"
    case longaoProgressivo = "Longão Progressivo"
    // Qualidade
    case tempoRun          = "Tempo Run"
    case intervalado       = "Intervalado"
    case fartlek           = "Fartlek"
    case subidas           = "Subidas"
    case strides           = "Strides"
    // Recovery
    case descanso          = "Descanso"
    case descansoAtivo     = "Descanso Ativo"

    var isRest: Bool {
        self == .descanso || self == .descansoAtivo
    }

    var isQuality: Bool {
        switch self {
        case .tempoRun, .intervalado, .fartlek, .subidas, .strides: return true
        default: return false
        }
    }

    var isLongRun: Bool {
        switch self {
        case .longaoLento, .longaoComRitmo, .longaoProgressivo: return true
        default: return false
        }
    }

    // Cor de intensidade para UI
    var intensityColor: WorkoutIntensity {
        switch self {
        case .descanso, .descansoAtivo:                         return .rest
        case .rodagemLeve, .longaoLento:                        return .easy
        case .rodagemModerada, .rodagemProgressiva, .fartlek,
             .strides, .longaoComRitmo, .longaoProgressivo:     return .moderate
        case .tempoRun, .intervalado, .subidas:                 return .hard
        }
    }

    // SF Symbol correspondente
    var sfSymbol: String {
        switch self {
        case .descanso:                                         return "moon.zzz.fill"
        case .descansoAtivo:                                    return "figure.walk"
        case .rodagemLeve, .rodagemModerada, .rodagemProgressiva: return "figure.run"
        case .longaoLento, .longaoComRitmo, .longaoProgressivo: return "road.lanes"
        case .tempoRun:                                         return "timer"
        case .intervalado:                                      return "repeat"
        case .fartlek:                                          return "shuffle"
        case .subidas:                                          return "mountain.2.fill"
        case .strides:                                          return "bolt.fill"
        }
    }
}

enum WorkoutIntensity {
    case rest, easy, moderate, hard
}

// MARK: - Sessão diária (formato exato do SYS_PLAN_WEEK)

struct DailyWorkout: Codable, Identifiable {
    var id: String { dia }
    let dia: String                   // "Segunda", "Terça", etc.
    let tipo: String                  // raw string do JSON
    let distancia_km: Double
    let pace_alvo: String             // "6:30-7:00/km" ou "6:30/km"
    let descricao: String
    let detalhe_treino: String        // breakdown: aquecimento + bloco + desaq
    let alerta_lesao: String

    var workoutType: WorkoutType {
        WorkoutType(rawValue: tipo) ?? .rodagemLeve
    }

    // Converte "6:30-7:00/km" para (lower: 390, upper: 420) em seg/km
    var paceRangeSec: (lower: Double, upper: Double)? {
        let cleaned = pace_alvo.replacingOccurrences(of: "/km", with: "")
        let parts = cleaned.split(separator: "-").map { String($0).trimmingCharacters(in: .whitespaces) }
        func toSec(_ s: String) -> Double? {
            let p = s.split(separator: ":").compactMap { Double($0) }
            guard p.count == 2 else { return nil }
            return p[0] * 60 + p[1]
        }
        if parts.count == 2, let lo = toSec(parts[0]), let hi = toSec(parts[1]) {
            return (lo, hi)
        } else if parts.count == 1, let v = toSec(parts[0]) {
            return (v * 0.97, v * 1.03)  // ±3% para alvo único
        }
        return nil
    }

    // Verifica se um pace ao vivo está dentro da zona alvo
    func isPaceOnTarget(_ currentPaceSec: Double) -> PaceStatus {
        guard !workoutType.isRest, currentPaceSec > 0, let range = paceRangeSec else { return .ok }
        if currentPaceSec < range.lower * 0.95 { return .tooFast }
        if currentPaceSec > range.upper * 1.05  { return .tooSlow }
        return .ok
    }
}

enum PaceStatus {
    case ok, tooFast, tooSlow
}

// MARK: - Semana de treino

struct TrainingWeek: Codable {
    let semana: Int
    let foco: String
    let volume_km: Double
    let treinos_chave: [String]
    let descansos: Int
    let resumo: String
    let intensidade: String
    var dias: [DailyWorkout]?         // expandido pelo SYS_PLAN_WEEK
}

// MARK: - Plano completo (espelha a tabela planos_treino)

struct TrainingPlan: Codable {
    let id: String
    let objetivo: String
    let nivel: String
    let semanas: [TrainingWeek]
    let resumo_semanal: String?
    let ativo: Bool

    // Retorna o treino do dia atual baseado no dia da semana
    func todayWorkout() -> DailyWorkout? {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // weekday: 1=Dom, 2=Seg ... 7=Sáb
        let names = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"]
        let todayName = names[weekday - 1]

        for week in semanas {
            if let dias = week.dias {
                return dias.first { $0.dia == todayName }
            }
        }
        return nil
    }

    // Semana atual (simplificado: primeira semana com dias expandidos)
    var currentWeek: TrainingWeek? {
        semanas.first { $0.dias != nil }
    }
}
