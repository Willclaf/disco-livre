// Disco Livre — gaveta lateral que mostra e libera espaço no Mac.
// Encoste o mouse na borda direita da tela e ela desliza pra dentro.
// Usa a ferramenta `disco-livre` (~/.local/bin) por baixo.

import AppKit
import CoreImage
import ServiceManagement
import SwiftUI

// MARK: - Ferramenta de linha de comando

enum CLI {
    static let casa = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
    static let caminho = casa + "/.local/bin/disco-livre"
    static let log = casa + "/Library/Logs/disco-livre.log"
    static var existe: Bool { FileManager.default.isExecutableFile(atPath: caminho) }

    static func rodar(_ args: [String]) async -> String {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/bin/zsh")
                p.arguments = [caminho] + args
                let saida = Pipe()
                p.standardOutput = saida
                p.standardError = FileHandle.nullDevice
                p.standardInput = FileHandle.nullDevice
                do { try p.run() } catch { cont.resume(returning: ""); return }
                let dados = saida.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                cont.resume(returning: String(decoding: dados, as: UTF8.self))
            }
        }
    }
}

// MARK: - Autoinstalação (pra quem baixou o .dmg e nunca abriu o Terminal)

enum Instalador {
    static let casa = CLI.casa

    /// "VERSAO=\"1.3.0\"" → "1.3.0"
    static func versao(_ caminho: String) -> String? {
        guard let txt = try? String(contentsOfFile: caminho, encoding: .utf8) else { return nil }
        for linha in txt.split(separator: "\n").prefix(30) where linha.hasPrefix("VERSAO=") {
            return linha.dropFirst(7).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        return nil
    }

    /// Instala ou atualiza a ferramenta que vem dentro do app. Na primeira vez,
    /// também liga a vigilância com a meta padrão (30 GB). Retorna true se instalou agora.
    @discardableResult
    static func garantir() async -> Bool {
        let fm = FileManager.default
        guard let embutida = Bundle.main.path(forResource: "disco-livre", ofType: nil) else { return false }
        let primeiraVez = !fm.fileExists(atPath: casa + "/.config/disco-livre/config")
        let atual = versao(CLI.caminho)
        if atual != nil && atual == versao(embutida) && !primeiraVez { return false }

        try? fm.createDirectory(atPath: casa + "/.local/bin", withIntermediateDirectories: true)
        try? fm.removeItem(atPath: CLI.caminho)
        guard (try? fm.copyItem(atPath: embutida, toPath: CLI.caminho)) != nil else { return false }
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: CLI.caminho)

        // skill pro Claude Code / Codex, se a pessoa usar
        if let skill = Bundle.main.path(forResource: "skill-disco-livre", ofType: nil) {
            for pasta in [".claude", ".codex"] where fm.fileExists(atPath: casa + "/" + pasta) {
                let destino = casa + "/" + pasta + "/skills/disco-livre"
                try? fm.createDirectory(atPath: casa + "/" + pasta + "/skills", withIntermediateDirectories: true)
                try? fm.removeItem(atPath: destino)
                try? fm.copyItem(atPath: skill, toPath: destino)
            }
        }

        // comando disco-livre no Terminal
        let zshrc = casa + "/.zshrc"
        let atualZsh = (try? String(contentsOfFile: zshrc, encoding: .utf8)) ?? ""
        if !atualZsh.contains(".local/bin") {
            let linha = "\n# disco-livre\nexport PATH=\"$HOME/.local/bin:$PATH\"\n"
            if let h = FileHandle(forWritingAtPath: zshrc) { h.seekToEndOfFile(); h.write(Data(linha.utf8)); h.closeFile() }
            else { try? linha.write(toFile: zshrc, atomically: true, encoding: .utf8) }
        }

        if primeiraVez {
            _ = await CLI.rodar(["config", "meta", "30"])
            _ = await CLI.rodar(["config", "auto-limpeza", "nao"])
            _ = await CLI.rodar(["ativar"])
        }
        return true
    }
}

// MARK: - Apoio (Pix)

enum Pix {
    static let chave = "c6a0d335-775a-4a2e-bb7a-2dfbf3f2cb67"
    static let nome = "Willian Claf"
    /// BR Code (padrão do Banco Central), valor livre
    static let copiaECola = "00020126580014br.gov.bcb.pix0136c6a0d335-775a-4a2e-bb7a-2dfbf3f2cb675204000053039865802BR5912WILLIAN CLAF6014SANTA CATARINA62070503***6304C34D"

    static func qr() -> NSImage? {
        guard let f = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        f.setValue(Data(copiaECola.utf8), forKey: "inputMessage")
        f.setValue("M", forKey: "inputCorrectionLevel")
        guard let img = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)) else { return nil }
        let rep = NSCIImageRep(ciImage: img)
        let ns = NSImage(size: rep.size)
        ns.addRepresentation(rep)
        return ns
    }

    static func copiar(_ texto: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(texto, forType: .string)
    }
}

// MARK: - Dados

struct Resumo: Decodable {
    var livre: Int64
    var total: Int64
    var metaKb: Int64
    var metaGb: Int
    var vigilancia: Bool
    var autoLimpeza: Bool
    var intervalo: Int
    var tendenciaKb: Int64?
    var primeiraFeita: Bool?   // opcional: ferramentas antigas não mandam
    var lixo: [Lixo]
    var crashes: [Crash]
    var tarefas: [Tarefa]
    var remoto: [Remoto]
}

struct Lixo: Decodable, Identifiable {
    var kb: Int64; var desc: String; var bloqueado: Bool; var cam: String
    var id: String { cam }
}

struct Crash: Decodable, Identifiable {
    var n: Int; var kb: Int64; var app: String; var cam: String
    var id: String { cam }
}

struct Tarefa: Decodable, Identifiable {
    var tipo: String; var label: String; var info: String; var prog: String
    var id: String { label }
}

struct Remoto: Decodable, Identifiable {
    var app: String; var porta: String; var perfil: String
    var id: String { app + porta }
}

struct ItemGeral: Decodable, Identifiable {
    var id: String; var nivel: String; var kb: Int64; var quem: String
    var desc: String; var nota: String; var lixeira: Bool
    var seguro: Bool { nivel == "seguro" }
    var bloqueado: Bool { !quem.isEmpty }
}

struct Geral: Decodable {
    var livre: Int64
    var itens: [ItemGeral]
}

struct Pulado: Decodable, Hashable { var desc: String; var quem: String }

struct ResultadoLimpeza: Decodable {
    var liberadoKb: Int64
    var lixeiraKb: Int64
    var itens: Int
    var livreAntes: Int64
    var livreDepois: Int64
    var pulados: [Pulado]
}

struct Pasta: Decodable, Identifiable {
    var kb: Int64; var cam: String; var oculta: Bool; var dica: String
    var id: String { cam }
    var nome: String { (cam as NSString).lastPathComponent }
    var curto: String { cam.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
}

/// GB/MB decimais, igual ao Finder.
func tamanho(_ kb: Int64) -> String {
    let b = Double(abs(kb)) * 1024
    let f = NumberFormatter()
    f.locale = Locale(identifier: "pt_BR")
    if b >= 1e9 {
        f.minimumFractionDigits = 1; f.maximumFractionDigits = 1
        return (f.string(from: NSNumber(value: b / 1e9)) ?? "") + " GB"
    }
    f.maximumFractionDigits = 0
    if b >= 1e6 { return (f.string(from: NSNumber(value: b / 1e6)) ?? "") + " MB" }
    return "\(abs(kb)) KB"
}

@MainActor
final class Estado: ObservableObject {
    @Published var resumo: Resumo?
    @Published var pastas: [Pasta]?
    @Published var carregando = false
    @Published var medindoPastas = false
    @Published var limpando = false
    @Published var aviso: String?

    // análise geral (primeira vez e sob demanda)
    enum FaseGeral { case fechada, analisando, lista, limpando, resultado }
    @Published var fase: FaseGeral = .fechada
    @Published var geral: Geral?
    @Published var marcados: Set<String> = []
    @Published var resultado: ResultadoLimpeza?
    @Published var esvaziandoLixeira = false
    @Published var lixeiraVazia = false
    @Published var mostrandoApoio = false
    @Published var novaVersao: String?
    @Published var atualizando = false

    static var versaoDoApp: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// verdadeiro se a versão a for mais nova que b ("1.10.0" > "1.9.2")
    static func maisNova(_ a: String, que b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }

    func checarAtualizacao() async {
        guard let url = URL(string: "https://api.github.com/repos/Willclaf/disco-livre/releases/latest"),
              let (dados, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: dados) as? [String: Any],
              let tag = json["tag_name"] as? String else { return }
        let v = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        novaVersao = Estado.maisNova(v, que: Estado.versaoDoApp) ? v : nil
    }

    /// Roda o atualizador da ferramenta. Ele fecha e reabre o app sozinho.
    func atualizarApp() {
        atualizando = true
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-c", "\"$HOME/.local/bin/disco-livre\" atualizar >> \"$HOME/Library/Logs/disco-livre.log\" 2>&1"]
        try? p.run()
    }

    var aoAtualizar: (() -> Void)?
    var pedirJanela: (() -> Void)?
    private var ultimaAtualizacao = Date.distantPast
    private var tarefaMeta: Task<Void, Never>?

    func atualizar(seVelho: Bool = false) async {
        guard CLI.existe else { aoAtualizar?(); return }
        if seVelho && Date().timeIntervalSince(ultimaAtualizacao) < 60 { return }
        if carregando { return }
        carregando = true
        let txt = await CLI.rodar(["dados", "resumo"])
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        if let r = try? dec.decode(Resumo.self, from: Data(txt.utf8)) {
            resumo = r
            ultimaAtualizacao = Date()
        }
        carregando = false
        aoAtualizar?()
    }

    func medirPastas() async {
        medindoPastas = true
        let txt = await CLI.rodar(["dados", "pastas"])
        pastas = (try? JSONDecoder().decode([Pasta].self, from: Data(txt.utf8))) ?? []
        medindoPastas = false
    }

    func limpar() async {
        let antes = resumo?.livre ?? 0
        limpando = true
        aviso = nil
        _ = await CLI.rodar(["limpar", "--executar", "--sim"])
        ultimaAtualizacao = .distantPast
        await atualizar()
        limpando = false
        let ganho = (resumo?.livre ?? 0) - antes
        aviso = ganho > 102_400 ? "Pronto! Liberei \(tamanho(ganho))." : "Pronto! Lixo limpo."
    }

    func mudarMeta(_ gb: Int) {
        resumo?.metaGb = gb
        resumo?.metaKb = Int64(gb) * 976_562
        aoAtualizar?()
        tarefaMeta?.cancel()
        tarefaMeta = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled { return }
            _ = await CLI.rodar(["config", "meta", "\(gb)"])
        }
    }

    func mudarVigilancia(_ ligar: Bool) async {
        resumo?.vigilancia = ligar
        _ = await CLI.rodar([ligar ? "ativar" : "desativar"])
        ultimaAtualizacao = .distantPast
        await atualizar()
    }

    func mudarAutoLimpeza(_ ligar: Bool) async {
        resumo?.autoLimpeza = ligar
        _ = await CLI.rodar(["config", "auto-limpeza", ligar ? "sim" : "nao"])
    }

    private func decodificador() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    func analisarGeral() async {
        fase = .analisando
        resultado = nil
        lixeiraVazia = false
        let txt = await CLI.rodar(["dados", "geral"])
        guard let g = try? decodificador().decode(Geral.self, from: Data(txt.utf8)) else {
            fase = .fechada
            aviso = "Não consegui fazer a análise agora."
            return
        }
        geral = g
        // já vem marcado só o que é seguro e pode ser limpo agora
        marcados = Set(g.itens.filter { $0.seguro && !$0.bloqueado }.map(\.id))
        fase = .lista
    }

    func alternar(_ item: ItemGeral) {
        guard !item.bloqueado else { return }
        if marcados.contains(item.id) { marcados.remove(item.id) } else { marcados.insert(item.id) }
    }

    var totalMarcado: Int64 {
        (geral?.itens ?? []).filter { marcados.contains($0.id) }.reduce(0) { $0 + $1.kb }
    }

    func limparMarcados() async {
        guard !marcados.isEmpty else { return }
        fase = .limpando
        let txt = await CLI.rodar(["limpar-itens"] + Array(marcados) + ["--json"])
        resultado = try? decodificador().decode(ResultadoLimpeza.self, from: Data(txt.utf8))
        fase = .resultado
        ultimaAtualizacao = .distantPast
        await atualizar()
    }

    func pularGeral() async {
        _ = await CLI.rodar(["geral", "--pular"])
        fase = .fechada
        ultimaAtualizacao = .distantPast
        await atualizar()
    }

    func concluirGeral() {
        fase = .fechada
        geral = nil
        resultado = nil
    }

    func esvaziarLixeira() async {
        esvaziandoLixeira = true
        _ = await CLI.rodar(["esvaziar-lixeira", "--sim"])
        esvaziandoLixeira = false
        lixeiraVazia = true
        ultimaAtualizacao = .distantPast
        await atualizar()
    }

    func pausar(_ label: String) async {
        _ = await CLI.rodar(["pausar-tarefa", label])
        ultimaAtualizacao = .distantPast
        await atualizar()
        aviso = "Tarefa \(label) pausada."
    }
}

// MARK: - Interface

struct BarraEspaco: View {
    let r: Resumo

    var cor: Color {
        if r.livre < r.metaKb { return .red }
        if r.livre < r.metaKb + r.metaKb / 3 { return .orange }
        return .green
    }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let usado = CGFloat(r.total - r.livre) / CGFloat(max(r.total, 1))
            let limite = CGFloat(r.total - r.metaKb) / CGFloat(max(r.total, 1))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule().fill(cor.gradient).frame(width: max(8, w * usado))
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.primary.opacity(0.75))
                    .frame(width: 2, height: 14)
                    .offset(x: w * limite - 1)
            }
        }
        .frame(height: 8)
        .padding(.vertical, 3)
        .help("A linha é a sua meta: o disco não deve encher além dela")
    }
}

/// Anel com o espaço livre no meio e um tique marcando a meta.
struct AnelEspaco: View {
    let r: Resumo

    var cores: [Color] {
        if r.livre < r.metaKb { return [.red, .pink] }
        if r.livre < r.metaKb + r.metaKb / 3 { return [.orange, .yellow] }
        return [Color(red: 0.16, green: 0.80, blue: 0.56), Color(red: 0.10, green: 0.55, blue: 0.95)]
    }

    var body: some View {
        let livre = CGFloat(r.livre) / CGFloat(max(r.total, 1))
        let meta = CGFloat(r.metaKb) / CGFloat(max(r.total, 1))
        ZStack {
            Circle().stroke(Color.primary.opacity(0.08), lineWidth: 7)
            Circle()
                .trim(from: 0, to: livre)
                .stroke(AngularGradient(colors: cores + [cores[0]], center: .center),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            // tique da meta
            Capsule()
                .fill(Color.primary.opacity(0.8))
                .frame(width: 2.5, height: 11)
                .offset(y: -29)
                .rotationEffect(.degrees(Double(meta) * 360))
            VStack(spacing: -2) {
                Text("\(Int((Double(r.livre) * 1024 / 1e9).rounded()))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("GB").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            }
        }
        .frame(width: 58, height: 58)
        .help("Anel = espaço livre. Tique = sua meta.")
    }
}

/// Ícone branco num quadradinho colorido, como nos Ajustes do Sistema.
struct IconeQuadrado: View {
    let simbolo: String
    let cor: Color

    var body: some View {
        Image(systemName: simbolo)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(cor.gradient))
    }
}

/// Uma linha "ícone · rótulo ........ valor" do resumo compacto.
struct Linha<Valor: View>: View {
    let icone: String
    let cor: Color
    let titulo: String
    @ViewBuilder var valor: Valor

    var body: some View {
        HStack(spacing: 10) {
            IconeQuadrado(simbolo: icone, cor: cor)
            Text(titulo)
            Spacer(minLength: 8)
            valor
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .frame(height: 38)
    }
}

/// Botão em cápsula com degradê.
struct Capsula: ButtonStyle {
    let cor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(cor.gradient))
            .shadow(color: cor.opacity(0.35), radius: 3, y: 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Fundo agrupado (estilo lista dos Ajustes).
struct Grupo<Conteudo: View>: View {
    @ViewBuilder var conteudo: Conteudo

    var body: some View {
        VStack(spacing: 0) { conteudo }
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
    }
}

struct Secao<Conteudo: View>: View {
    let titulo: String
    @ViewBuilder var conteudo: Conteudo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            conteudo
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PainelView: View {
    @EnvironmentObject var e: Estado
    @State private var detalhes = false
    @State private var confirmando = false
    @State private var iniciarComMac = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !CLI.existe {
                semFerramenta
            } else if e.mostrandoApoio {
                ApoioView()
            } else if e.fase != .fechada {
                AnaliseGeralView()
            } else if let r = e.resumo {
                resumo(r).padding(14)
                if detalhes {
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            alertas(r)
                            lixoDetalhado(r)
                            pastas
                            ajustes(r)
                        }
                        .padding(14)
                    }
                    .frame(maxHeight: 420)
                }
                Divider()
                rodape(r)
            } else {
                HStack { ProgressView().controlSize(.small); Text("Olhando o disco…").foregroundStyle(.secondary) }
                    .padding(20)
            }
        }
        .frame(width: e.fase == .fechada || e.mostrandoApoio ? 300 : 340)
        .animation(.easeInOut(duration: 0.2), value: detalhes)
        .animation(.easeInOut(duration: 0.25), value: e.fase)
        .animation(.easeInOut(duration: 0.25), value: e.mostrandoApoio)
    }

    var semFerramenta: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Falta instalar a ferramenta").font(.headline)
            Text("Na pasta do disco-livre, rode ./install.sh no Terminal.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
    }

    // ── as 4 coisas ──────────────────────────────────────────────────────

    func resumo(_ r: Resumo) -> some View {
        let total = r.lixo.filter { !$0.bloqueado }.reduce(Int64(0)) { $0 + $1.kb }
        let ok = r.livre >= r.metaKb
        return VStack(alignment: .leading, spacing: 12) {
            // 1. espaço livre
            HStack(spacing: 14) {
                AnelEspaco(r: r)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Espaço livre").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Text(tamanho(r.livre)).font(.system(size: 22, weight: .bold, design: .rounded))
                    HStack(spacing: 4) {
                        Circle().fill(ok ? Color.green : Color.red).frame(width: 6, height: 6)
                        Text(ok ? "\(tamanho(r.livre - r.metaKb)) acima da meta"
                                : "faltam \(tamanho(r.metaKb - r.livre)) pra meta")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(ok ? Color.secondary : Color.red)
                }
                Spacer()
                if e.carregando { ProgressView().controlSize(.mini) }
            }

            Grupo {
                // 2. meta
                Linha(icone: "flag.fill", cor: .blue, titulo: "Meta") {
                    HStack(spacing: 2) {
                        Button { e.mudarMeta(max(5, r.metaGb - 5)) } label: {
                            Image(systemName: "minus").frame(width: 20, height: 20)
                        }
                        Text("\(r.metaGb) GB").monospacedDigit().fontWeight(.semibold).frame(minWidth: 46)
                        Button { e.mudarMeta(min(500, r.metaGb + 5)) } label: {
                            Image(systemName: "plus").frame(width: 20, height: 20)
                        }
                    }
                    .buttonStyle(.borderless)
                    .padding(.horizontal, 4)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                }
                Divider().padding(.leading, 42)
                // 3. vigia
                Linha(icone: r.vigilancia ? "eye.fill" : "eye.slash.fill", cor: r.vigilancia ? .purple : .gray, titulo: "Vigia") {
                    Text(r.vigilancia ? "a cada \(r.intervalo)h" : "desligado")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Toggle("", isOn: Binding(get: { r.vigilancia }, set: { v in Task { await e.mudarVigilancia(v) } }))
                        .toggleStyle(.switch).controlSize(.mini).labelsHidden()
                }
                Divider().padding(.leading, 42)
                // 4. pra limpar
                Linha(icone: "sparkles", cor: .green, titulo: "Pra limpar") {
                    if e.limpando {
                        ProgressView().controlSize(.mini)
                    } else if total == 0 {
                        Text("nada 👌").foregroundStyle(.secondary)
                    } else {
                        Text(tamanho(total)).monospacedDigit().foregroundStyle(.secondary)
                        Button(confirmando ? "Confirmar" : "Limpar") {
                            if confirmando {
                                confirmando = false
                                Task { await e.limpar() }
                            } else {
                                confirmando = true
                            }
                        }
                        .buttonStyle(Capsula(cor: confirmando ? .orange : .green))
                        .help("Apaga só cache, logs velhos e relatórios de crash. Tudo se recria sozinho.")
                    }
                }
            }

            if confirmando {
                HStack {
                    Text("Apagar \(tamanho(total)) de lixo seguro?").font(.caption)
                    Spacer()
                    Button("Cancelar") { confirmando = false }.buttonStyle(.borderless).font(.caption)
                }
            }
            if let a = e.aviso {
                Label(a, systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
            }
        }
    }

    func rodape(_ r: Resumo) -> some View {
        let alertas = r.crashes.count + r.tarefas.count + r.remoto.count
        return HStack {
            Button {
                detalhes.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(detalhes ? "Ver menos" : "Ver mais")
                    Image(systemName: detalhes ? "chevron.up" : "chevron.down").font(.caption2)
                    if alertas > 0 && !detalhes {
                        Text("\(alertas) alerta\(alertas > 1 ? "s" : "")")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(Color.orange.opacity(0.2)))
                            .foregroundStyle(.orange)
                    }
                }
            }
            Spacer()
            if let v = e.novaVersao {
                Button { e.atualizarApp() } label: {
                    if e.atualizando {
                        ProgressView().controlSize(.mini)
                    } else {
                        Text("⬆️ \(v)")
                    }
                }
                .buttonStyle(Capsula(cor: .blue))
                .disabled(e.atualizando)
                .help("Versão nova do Disco Livre. Clique pra atualizar (suas configurações ficam).")
            }
            Button { e.mostrandoApoio = true } label: { Text("☕").font(.system(size: 14)) }
                .help("Me paga um café — o Disco Livre é grátis")
            Button { e.pedirJanela?() } label: { Image(systemName: "macwindow") }
                .help("Abrir como janela")
            Button { Task { await e.atualizar() } } label: { Image(systemName: "arrow.clockwise") }
                .help("Atualizar")
        }
        .buttonStyle(.borderless)
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    // ── detalhes (Ver mais) ──────────────────────────────────────────────

    @ViewBuilder
    func alertas(_ r: Resumo) -> some View {
        if !r.crashes.isEmpty || !r.tarefas.isEmpty || !r.remoto.isEmpty {
            Secao(titulo: "Alertas") {
                ForEach(r.crashes) { c in
                    alerta("xmark.octagon.fill", .red, "\(c.app) está crashando sem parar",
                           "\(c.n) relatórios de crash (\(tamanho(c.kb))). Limpe e reinicie o app.")
                }
                ForEach(r.tarefas) { t in
                    HStack(alignment: .top) {
                        alerta(t.tipo == "reabre" ? "arrow.triangle.2.circlepath" : "exclamationmark.circle.fill",
                               t.tipo == "reabre" ? .orange : .red, t.label,
                               t.tipo == "reabre" ? "Abre o \(t.info) sozinho e reabre se você fechar."
                                                  : "Tarefa em segundo plano dando erro (código \(t.info)).")
                        Button("Pausar") { Task { await e.pausar(t.label) } }
                            .controlSize(.mini)
                            .help("Para a tarefa (reversível: disco-livre religar-tarefa \(t.label))")
                    }
                }
                ForEach(r.remoto) { rm in
                    alerta("dot.radiowaves.left.and.right", .orange, "\(rm.app) com controle remoto ligado",
                           "Qualquer programa pode comandar esse navegador. Se não é automação sua, feche.")
                }
            }
        }
    }

    func alerta(_ icone: String, _ cor: Color, _ titulo: String, _ texto: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icone).foregroundStyle(cor).font(.caption).frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(titulo).font(.caption.weight(.medium)).lineLimit(2)
                Text(texto).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    func lixoDetalhado(_ r: Resumo) -> some View {
        Secao(titulo: "O que dá pra limpar") {
            if r.lixo.isEmpty {
                Text("Nada no momento.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(r.lixo.sorted { $0.kb > $1.kb }) { i in
                HStack {
                    Text(i.desc).lineLimit(1)
                    if i.bloqueado {
                        Text("feche o app").font(.caption2).foregroundStyle(.orange)
                    }
                    Spacer()
                    Text(tamanho(i.kb)).monospacedDigit().foregroundStyle(.secondary)
                }
                .font(.caption)
                .opacity(i.bloqueado ? 0.55 : 1)
            }
        }
    }

    var pastas: some View {
        Secao(titulo: "Maiores pastas") {
            if e.medindoPastas {
                HStack { ProgressView().controlSize(.mini); Text("Medindo… uns 15 s").foregroundStyle(.secondary) }
                    .font(.caption)
            } else if let lista = e.pastas {
                ForEach(lista.prefix(10)) { p in
                    HStack(spacing: 4) {
                        Text(p.nome).lineLimit(1).truncationMode(.middle)
                        if p.oculta {
                            Text("oculta").font(.system(size: 9, weight: .semibold)).foregroundStyle(.orange)
                        }
                        Spacer()
                        Text(tamanho(p.kb)).monospacedDigit().foregroundStyle(.secondary)
                        Button { NSWorkspace.shared.open(URL(fileURLWithPath: p.cam)) } label: {
                            Image(systemName: "arrow.up.forward.square")
                        }
                        .buttonStyle(.borderless)
                        .help(p.dica.isEmpty ? "Abrir no Finder: \(p.curto)" : "\(p.dica)\n\(p.curto)")
                    }
                    .font(.caption)
                }
            } else {
                Button("Medir pastas (inclusive as ocultas)") { Task { await e.medirPastas() } }
                    .controlSize(.small)
            }
        }
    }

    func ajustes(_ r: Resumo) -> some View {
        Secao(titulo: "Ajustes") {
            Toggle("Limpar sozinho abaixo da meta",
                   isOn: Binding(get: { r.autoLimpeza }, set: { v in Task { await e.mudarAutoLimpeza(v) } }))
                .disabled(!r.vigilancia)
            Toggle("Abrir ao ligar o Mac", isOn: Binding(get: { iniciarComMac }, set: { v in
                do {
                    if v { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                } catch {}
                iniciarComMac = SMAppService.mainApp.status == .enabled
            }))
            Button {
                Task { await e.analisarGeral() }
            } label: {
                Label("Fazer análise geral do Mac", systemImage: "wand.and.stars")
            }
            .controlSize(.small)
            HStack {
                Button("Histórico") { NSWorkspace.shared.open(URL(fileURLWithPath: CLI.log)) }
                Spacer()
                Button("Sair") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .padding(.top, 2)
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .font(.caption)
    }
}

// MARK: - Análise geral (boas-vindas)

struct AnaliseGeralView: View {
    @EnvironmentObject var e: Estado
    @State private var confirmandoLixeira = false
    @State private var pulse = false
    @State private var festa = false
    @State private var cafeCopiado = false

    var body: some View {
        switch e.fase {
        case .analisando: analisando
        case .lista: lista
        case .limpando: limpando
        case .resultado: resultado
        case .fechada: EmptyView()
        }
    }

    // 1. procurando
    var analisando: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.green.opacity(0.12)).frame(width: 74, height: 74)
                    .scaleEffect(pulse ? 1.15 : 0.9)
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [.green, .blue], startPoint: .top, endPoint: .bottom))
            }
            .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { pulse = true } }
            VStack(spacing: 4) {
                Text(e.resumo?.primeiraFeita == false ? "Bem-vindo ao Disco Livre 👋" : "Análise geral")
                    .font(.headline)
                Text("Procurando espaço escondido no seu Mac…")
                    .font(.callout).foregroundStyle(.secondary)
                Text("caches, relatórios de crash, logs, IA e mais")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            ProgressView().controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // 2. lista pra escolher
    var lista: some View {
        let itens = e.geral?.itens ?? []
        let total = itens.reduce(Int64(0)) { $0 + $1.kb }
        let seguros = itens.filter(\.seguro)
        let revisar = itens.filter { !$0.seguro }
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(itens.isEmpty ? "Tudo limpo por aqui" : "Encontrei")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                if !itens.isEmpty {
                    Text(tamanho(total))
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [Color(red: 0.16, green: 0.80, blue: 0.56),
                                                                 Color(red: 0.10, green: 0.55, blue: 0.95)],
                                                        startPoint: .leading, endPoint: .trailing))
                    Text("que dá pra liberar no seu Mac. Escolha o que limpar:")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Text("Seu Mac não tem lixo escondido agora 👌").font(.callout)
                }
            }
            .padding(14)

            if !itens.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if !seguros.isEmpty {
                            grupo("Seguro", "se recria sozinho, não perde nada", seguros)
                        }
                        if !revisar.isEmpty {
                            grupo("Revise", "é seu: só sai se você marcar", revisar)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }
                .frame(maxHeight: 360)
            }

            Divider()
            VStack(spacing: 8) {
                if !itens.isEmpty {
                    Button {
                        Task { await e.limparMarcados() }
                    } label: {
                        Text(e.marcados.isEmpty ? "Marque o que quer limpar" : "Liberar \(tamanho(e.totalMarcado))")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(Capsula(cor: .green))
                    .disabled(e.marcados.isEmpty)
                    .opacity(e.marcados.isEmpty ? 0.5 : 1)
                }
                HStack {
                    if itens.contains(where: \.bloqueado) {
                        Button("Fechei os apps, conferir de novo") { Task { await e.analisarGeral() } }
                    }
                    Spacer()
                    Button(itens.isEmpty ? "Fechar" : "Agora não") { Task { await e.pularGeral() } }
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(14)
        }
    }

    func grupo(_ titulo: String, _ sub: String, _ itens: [ItemGeral]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(titulo).font(.system(size: 11, weight: .bold)).textCase(.uppercase)
                Text(sub).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Grupo {
                ForEach(Array(itens.enumerated()), id: \.element.id) { i, item in
                    if i > 0 { Divider().padding(.leading, 38) }
                    linha(item)
                }
            }
        }
    }

    func linha(_ item: ItemGeral) -> some View {
        let marcado = e.marcados.contains(item.id)
        return Button { e.alternar(item) } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: item.bloqueado ? "lock.circle" : (marcado ? "checkmark.circle.fill" : "circle"))
                    .font(.system(size: 17))
                    .foregroundStyle(item.bloqueado ? Color.orange : (marcado ? Color.green : Color.secondary))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.desc).font(.system(size: 12.5)).lineLimit(2).multilineTextAlignment(.leading)
                    if item.bloqueado {
                        Text("Feche o \(item.quem) pra limpar").font(.caption2).foregroundStyle(.orange)
                    } else if !item.nota.isEmpty {
                        Text(item.nota).font(.caption2).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 6)
                Text(tamanho(item.kb)).font(.system(size: 12, weight: .medium)).monospacedDigit()
                    .foregroundStyle(marcado ? Color.primary : Color.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(item.bloqueado ? 0.65 : 1)
        .help(item.bloqueado ? "Esse app está aberto. Feche e clique em \"conferir de novo\"." : "")
    }

    // 3. limpando
    var limpando: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Liberando \(tamanho(e.totalMarcado))…").font(.callout)
            Text("Não feche os apps agora").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    // 4. resultado
    var resultado: some View {
        let r = e.resultado
        let liberado = r?.liberadoKb ?? 0
        return VStack(spacing: 14) {
            Text(liberado > 0 ? "🎉" : "✅")
                .font(.system(size: 52))
                .scaleEffect(festa ? 1 : 0.3)
                .rotationEffect(.degrees(festa ? 0 : -25))
                .onAppear { withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { festa = true } }
            VStack(spacing: 2) {
                Text(liberado > 0 ? "Você liberou" : "Pronto!").font(.callout).foregroundStyle(.secondary)
                if liberado > 0 {
                    Text(tamanho(liberado))
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [Color(red: 0.16, green: 0.80, blue: 0.56),
                                                                 Color(red: 0.10, green: 0.55, blue: 0.95)],
                                                        startPoint: .leading, endPoint: .trailing))
                    Text("que estavam escondidos").font(.callout).foregroundStyle(.secondary)
                }
            }
            if let r {
                HStack(spacing: 8) {
                    VStack(spacing: 1) {
                        Text("antes").font(.caption2).foregroundStyle(.secondary)
                        Text(tamanho(r.livreAntes)).font(.callout.weight(.semibold)).monospacedDigit()
                    }
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    VStack(spacing: 1) {
                        Text("agora livres").font(.caption2).foregroundStyle(.secondary)
                        Text(tamanho(e.resumo?.livre ?? r.livreDepois)).font(.callout.weight(.bold)).monospacedDigit()
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(Color.primary.opacity(0.05)))

                if r.lixeiraKb > 0 { cartaoLixeira(r.lixeiraKb) }

                if !r.pulados.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(r.pulados, id: \.self) { p in
                            Label("Pulei \(p.desc): o \(p.quem) estava aberto", systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                }
            }
            if liberado >= 10 * 1_048_576 { cartaoCafe(liberado) }
            Button { e.concluirGeral() } label: { Text("Concluir").frame(maxWidth: .infinity) }
                .buttonStyle(Capsula(cor: .blue))
            if liberado > 0 && liberado < 10 * 1_048_576 {
                Button { e.mostrandoApoio = true } label: {
                    Text("☕ Curtiu? Me paga um café").font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
    }

    /// Só aparece quando a limpeza liberou 10 GB ou mais: é quando a pessoa sentiu o valor.
    func cartaoCafe(_ kb: Int64) -> some View {
        HStack(spacing: 12) {
            if let qr = Pix.qr() {
                Image(nsImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 84, height: 84)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white))
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("☕ Que tal me pagar um café?").font(.callout.weight(.semibold))
                Text("Foram \(tamanho(kb)) a menos no seu Mac. O Disco Livre é grátis e vai continuar assim: um Pix de qualquer valor me ajuda a mantê-lo.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Pix.copiar(Pix.copiaECola)
                    cafeCopiado = true
                } label: {
                    Text(cafeCopiado ? "Pix copiado ✓" : "Copiar Pix Copia e Cola")
                }
                .buttonStyle(Capsula(cor: .green))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.green.opacity(0.08)))
    }

    func cartaoLixeira(_ kb: Int64) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                IconeQuadrado(simbolo: "trash.fill", cor: .gray)
                VStack(alignment: .leading, spacing: 1) {
                    Text(e.lixeiraVazia ? "Lixeira esvaziada ✓" : "Mais \(tamanho(kb)) foram pra Lixeira")
                        .font(.callout.weight(.medium))
                    Text(e.lixeiraVazia ? "Espaço liberado de vez." : "Ainda dá pra recuperar. Esvazie pra liberar de vez.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if !e.lixeiraVazia {
                if e.esvaziandoLixeira {
                    HStack { ProgressView().controlSize(.mini); Text("Esvaziando…").font(.caption) }
                } else if confirmandoLixeira {
                    HStack {
                        Text("Apaga de vez tudo da Lixeira.").font(.caption)
                        Spacer()
                        Button("Cancelar") { confirmandoLixeira = false }.buttonStyle(.borderless).font(.caption)
                        Button("Esvaziar") {
                            confirmandoLixeira = false
                            Task { await e.esvaziarLixeira() }
                        }
                        .buttonStyle(Capsula(cor: .red))
                    }
                } else {
                    Button("Esvaziar Lixeira") { confirmandoLixeira = true }
                        .buttonStyle(Capsula(cor: .gray))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
    }
}

// MARK: - Me paga um café

struct ApoioView: View {
    @EnvironmentObject var e: Estado
    @State private var copiado: String?
    @State private var vapor = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { e.mostrandoApoio = false } label: {
                    Label("Voltar", systemImage: "chevron.left").font(.caption)
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            Text("☕")
                .font(.system(size: 40))
                .offset(y: vapor ? -2 : 2)
                .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever()) { vapor = true } }
            VStack(spacing: 4) {
                Text("Me paga um café?").font(.headline)
                Text("O Disco Livre é grátis e vai continuar grátis. Se ele te ajudou, um Pix de qualquer valor me ajuda a manter e melhorar.")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let qr = Pix.qr() {
                Image(nsImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 160, height: 160)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                    .help("Aponte a câmera do app do seu banco")
            }
            Text("Aponte a câmera do app do banco").font(.caption2).foregroundStyle(.secondary)

            Button {
                Pix.copiar(Pix.copiaECola)
                copiado = "Pix Copia e Cola copiado ✓"
            } label: {
                Label("Copiar Pix Copia e Cola", systemImage: "doc.on.doc").frame(maxWidth: .infinity)
            }
            .buttonStyle(Capsula(cor: .green))

            Button("Copiar só a chave") {
                Pix.copiar(Pix.chave)
                copiado = "Chave Pix copiada ✓"
            }
            .buttonStyle(.borderless)
            .font(.caption)

            if let c = copiado {
                Text(c).font(.caption).foregroundStyle(.green)
            }
            Text(Pix.nome).font(.caption2).foregroundStyle(.tertiary)
            Text("Valeu demais! 💚").font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - App (ícone na barra de menus + popover)

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let estado = Estado()
    let popover = NSPopover()
    var item: NSStatusItem!
    var monitores: [Any] = []
    var timerAbrir: Timer?
    var timerFechar: Timer?
    var fixo = false   // aberto com clique: só fecha com clique fora
    var janela: NSWindow?

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = item.button {
            b.image = NSImage(systemSymbolName: "internaldrive", accessibilityDescription: "Disco Livre")
            b.imagePosition = .imageLeading
            b.target = self
            b.action = #selector(cliqueNoIcone)
        }

        let host = NSHostingController(rootView: PainelView().environmentObject(estado))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        popover.behavior = .applicationDefined
        popover.animates = true

        estado.aoAtualizar = { [weak self] in self?.atualizarIcone() }
        estado.pedirJanela = { [weak self] in self?.abrirJanela() }

        // passar o mouse no ícone abre; sair de perto fecha
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved], handler: { [weak self] _ in
            Task { @MainActor in self?.mouseMexeu() }
        }) { monitores.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved], handler: { [weak self] ev in
            Task { @MainActor in self?.mouseMexeu() }
            return ev
        }) { monitores.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            Task { @MainActor in self?.fechar() }
        }) { monitores.append(m) }

        Task {
            await Instalador.garantir()   // instalou pelo .dmg? a ferramenta vem junto
            await estado.atualizar()
            // primeira vez (ou instalador pediu): abre sozinho e já faz a análise geral
            let boasVindas = CommandLine.arguments.contains("--boas-vindas")
            let primeira = boasVindas || estado.resumo?.primeiraFeita == false
            if primeira {
                abrir(fixo: true)
                await estado.analisarGeral()
            }
            await perguntarAbrirAoLigar()
            // aberto por quem clicou no app (e não pelo login): mostra a janela
            if !boasVindas && !primeira && !abriuNoLogin() && CommandLine.arguments.count == 1 { abrirJanela() }
        }
        if CommandLine.arguments.contains("--mostrar") { abrir(fixo: true) }
        Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.estado.atualizar() }
        }
        // versão nova: confere ao abrir e a cada 6 h
        Task { await estado.checarAtualizacao() }
        Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.estado.checarAtualizacao() }
        }
    }

    // MARK: janela (app de verdade), pergunta do login e ícone

    /// Abre o app numa janela normal (Dock + Cmd-Tab) além do ícone da barra.
    func abrirJanela() {
        fechar(forcar: true)
        if janela == nil {
            let host = NSHostingController(rootView: PainelView().environmentObject(estado))
            host.sizingOptions = [.preferredContentSize]
            let w = NSWindow(contentViewController: host)
            w.title = "Disco Livre"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.center()
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.janela = nil
                    NSApp.setActivationPolicy(.accessory)
                }
            }
            janela = w
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        janela?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        abrirJanela()
        return true
    }

    /// O macOS abriu o app sozinho no login? (nesse caso não mostra janela)
    func abriuNoLogin() -> Bool {
        let ev = NSAppleEventManager.shared().currentAppleEvent
        return ev?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == AEKeyword(keyAELaunchedAsLogInItem)
    }

    /// Pergunta uma única vez se a pessoa quer abrir ao ligar o Mac.
    func perguntarAbrirAoLigar() async {
        let d = UserDefaults.standard
        guard !d.bool(forKey: "askedLaunchAtLogin") else { return }
        d.set(true, forKey: "askedLaunchAtLogin")
        if SMAppService.mainApp.status == .enabled { return }
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "Abrir o Disco Livre quando ligar o Mac?"
        a.informativeText = "Assim o ícone fica sempre na barra de cima, de olho no seu espaço livre. Você pode mudar isso depois em Ajustes."
        a.addButton(withTitle: "Sim, abrir ao ligar")
        a.addButton(withTitle: "Agora não")
        if a.runModal() == .alertFirstButtonReturn { try? SMAppService.mainApp.register() }
    }

    /// Ícone da barra: anel que mostra quanto do disco está livre.
    func ring(_ free: Double, alert: Bool) -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let c = NSPoint(x: 9, y: 9)
            let cor: NSColor = alert ? .systemRed : .black
            cor.withAlphaComponent(0.28).setStroke()
            let trilho = NSBezierPath()
            trilho.appendArc(withCenter: c, radius: 6.5, startAngle: 0, endAngle: 360)
            trilho.lineWidth = 2.2
            trilho.stroke()
            cor.setStroke()
            let arco = NSBezierPath()
            arco.appendArc(withCenter: c, radius: 6.5, startAngle: 90, endAngle: 90 - 360 * CGFloat(max(0.03, min(1, free))), clockwise: true)
            arco.lineWidth = 2.2
            arco.lineCapStyle = .round
            arco.stroke()
            cor.setFill()
            NSBezierPath(ovalIn: NSRect(x: 7.2, y: 7.2, width: 3.6, height: 3.6)).fill()
            return true
        }
        img.isTemplate = !alert
        return img
    }

    func atualizarIcone() {
        guard let b = item.button else { return }
        guard let r = estado.resumo else { b.title = ""; return }
        let gb = Int((Double(r.livre) * 1024 / 1e9).rounded())
        let abaixo = r.livre < r.metaKb
        b.title = " \(gb) GB"
        b.image = ring(Double(r.livre) / Double(max(r.total, 1)), alert: abaixo)
        b.contentTintColor = nil
    }

    var areaDoIcone: NSRect {
        guard let b = item.button, let w = b.window else { return .zero }
        return w.convertToScreen(b.convert(b.bounds, to: nil))
    }

    var areaDoPopover: NSRect {
        popover.contentViewController?.view.window?.frame ?? .zero
    }

    func mouseMexeu() {
        let p = NSEvent.mouseLocation
        let noIcone = areaDoIcone.insetBy(dx: -2, dy: -2).contains(p)
        if !popover.isShown {
            if noIcone {
                if timerAbrir == nil {
                    timerAbrir = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                        Task { @MainActor in
                            guard let self else { return }
                            self.timerAbrir = nil
                            if self.areaDoIcone.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) {
                                self.abrir(fixo: false)
                            }
                        }
                    }
                }
            } else {
                timerAbrir?.invalidate(); timerAbrir = nil
            }
            return
        }
        guard !fixo else { return }
        let perto = noIcone || areaDoPopover.insetBy(dx: -16, dy: -16).contains(p)
        if perto {
            timerFechar?.invalidate(); timerFechar = nil
        } else if timerFechar == nil {
            timerFechar = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.timerFechar = nil
                    let q = NSEvent.mouseLocation
                    if !self.areaDoIcone.contains(q) && !self.areaDoPopover.insetBy(dx: -16, dy: -16).contains(q) {
                        self.fechar(forcar: true)
                    }
                }
            }
        }
    }

    @objc func cliqueNoIcone() {
        if popover.isShown && fixo {
            fechar(forcar: true)
        } else if popover.isShown {
            fixo = true   // estava aberto pelo mouse: o clique "prende"
        } else {
            abrir(fixo: true)
        }
    }

    func abrir(fixo: Bool) {
        guard let b = item.button else { return }
        self.fixo = fixo
        popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        Task { await estado.atualizar(seVelho: true) }
    }

    func fechar(forcar: Bool = false) {
        guard popover.isShown else { return }
        if !forcar && areaDoPopover.contains(NSEvent.mouseLocation) { return }
        timerFechar?.invalidate(); timerFechar = nil
        fixo = false
        popover.performClose(nil)
    }
}

@main
enum DiscoLivreApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = MainActor.assumeIsolated { AppDelegate() }
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
