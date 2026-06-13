import Foundation

// MARK: - CrashReporter
// Captura crashes que não aparecem no Xcode (TestFlight sem Mac):
//  - NSException (Objective-C) via NSSetUncaughtExceptionHandler
//  - Swift traps / sinais (SIGABRT, SIGILL, SIGSEGV, etc.) via signal()
// Persiste o motivo + backtrace + "breadcrumbs" em UserDefaults e mostra na
// próxima abertura. Como o build de TestFlight não tem símbolos legíveis, os
// breadcrumbs (último passo executado) são a pista mais confiável: mostram
// EXATAMENTE onde o app morreu.
//
// Os handlers usam string literal para a chave (em vez de referenciar uma
// constante estática) para garantir que continuem conversíveis em ponteiros
// de função C (@convention(c)) — sem captura de contexto.

enum CrashReporter {
    private static let reportKey  = "lastCrashReport"
    private static let crumbsKey  = "breadcrumbs"
    private static let attemptKey = "attemptInProgress"

    // MARK: Instalação dos handlers

    static func install() {
        NSSetUncaughtExceptionHandler { exception in
            let symbols = exception.callStackSymbols.prefix(15).joined(separator: "\n")
            let report = """
            ⚠️ NSException
            \(exception.name.rawValue)
            \(exception.reason ?? "sem motivo")

            \(symbols)
            """
            UserDefaults.standard.set(report, forKey: "lastCrashReport")
        }

        let handledSignals: [Int32] = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGTRAP]
        for sig in handledSignals {
            signal(sig) { received in
                let name: String
                switch received {
                case SIGABRT: name = "SIGABRT (abort/assert)"
                case SIGILL:  name = "SIGILL (instrução inválida / Swift trap)"
                case SIGSEGV: name = "SIGSEGV (memória inválida)"
                case SIGFPE:  name = "SIGFPE (erro aritmético)"
                case SIGBUS:  name = "SIGBUS (acesso inválido)"
                case SIGTRAP: name = "SIGTRAP (Swift fatalError/precondition)"
                default:      name = "Signal \(received)"
                }
                let symbols = Thread.callStackSymbols.prefix(15).joined(separator: "\n")
                let report = "⚠️ \(name)\n\n\(symbols)"
                UserDefaults.standard.set(report, forKey: "lastCrashReport")
                signal(received, SIG_DFL)
                raise(received)
            }
        }
    }

    // MARK: Breadcrumbs (último passo executado)

    /// Registra um passo. Mantém os últimos 25 em UserDefaults.
    static func breadcrumb(_ step: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        let line = "\(f.string(from: Date())) \(step)"
        var list = UserDefaults.standard.stringArray(forKey: crumbsKey) ?? []
        list.append(line)
        if list.count > 25 { list.removeFirst(list.count - 25) }
        UserDefaults.standard.set(list, forKey: crumbsKey)
        print("🍞 \(line)")
    }

    static func breadcrumbsText() -> String {
        (UserDefaults.standard.stringArray(forKey: crumbsKey) ?? []).joined(separator: "\n")
    }

    // MARK: Tentativa de início (cobre kills que os handlers não pegam:
    // watchdog, falta de memória, etc.)

    /// Marca que uma tentativa de iniciar corrida começou.
    static func beginAttempt() {
        UserDefaults.standard.set(true, forKey: attemptKey)
    }

    /// Marca que a tentativa chegou a um estado estável (UI de corrida na tela).
    static func endAttempt() {
        UserDefaults.standard.set(false, forKey: attemptKey)
    }

    private static func attemptFailed() -> Bool {
        UserDefaults.standard.bool(forKey: attemptKey)
    }

    // MARK: Leitura / limpeza

    static func pendingReport() -> String? {
        UserDefaults.standard.string(forKey: reportKey)
    }

    /// Deve mostrar o diagnóstico? Sim se houve crash capturado OU se a última
    /// tentativa de início nunca chegou à tela de corrida (kill silencioso).
    static func shouldShowDiagnostics() -> Bool {
        pendingReport() != nil || attemptFailed()
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: reportKey)
        UserDefaults.standard.removeObject(forKey: crumbsKey)
        UserDefaults.standard.removeObject(forKey: attemptKey)
    }
}
