import SwiftUI
import UniformTypeIdentifiers

// MARK: - Tab Ajustes: tema, clave de Gemini, datos, importar/exportar

struct AjustesView: View {
    @EnvironmentObject private var store: QVStore
    @Environment(\.colorScheme) private var scheme
    @State private var keyInput = ""
    @State private var keyState = ""
    @State private var checkingKey = false
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var importingSeed = false
    @State private var exportDoc: QVJSONDocument?

    private var isDark: Bool { store.darkOverride ?? (scheme == .dark) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    QVHeader()
                    themeCard
                    geminiCard
                    datosCard
                    backupCard
                    Text("Qué ver v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") · hecha con el estilo Jelly 🍮")
                        .font(.caption)
                        .foregroundStyle(Color.ink2(scheme).opacity(0.7))
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .fileExporter(isPresented: $showExporter, document: exportDoc, contentType: .json, defaultFilename: "que-ver-datos.json") { _ in }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result {
                let ok = url.startAccessingSecurityScopedResource()
                defer { if ok { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    do {
                        let n = try store.importData(data)
                        ToastCenter.shared.show("Importados \(n) títulos ✓")
                    } catch {
                        ToastCenter.shared.show("No he podido leer ese archivo")
                    }
                }
            }
        }
    }

    // MARK: Tema

    private var themeCard: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apariencia")
                        .font(.headline)
                        .foregroundStyle(Color.ink(scheme))
                    Text("Como tu iPhone o a tu gusto")
                        .font(.caption)
                        .foregroundStyle(Color.ink2(scheme))
                }
                Spacer()
                SunMoonToggle(isDark: Binding(
                    get: { isDark },
                    set: { store.darkOverride = $0 == (scheme == .dark) ? nil : $0 }
                ))
            }
        }
    }

    // MARK: Gemini

    private var geminiCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Búsqueda por descripción (IA)")
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.ink2(scheme))
                Text("Usa tu propia clave gratuita de Google AI Studio. Se guarda solo en este dispositivo.")
                    .font(.caption)
                    .foregroundStyle(Color.ink2(scheme))
                HStack(spacing: 8) {
                    SecureField("Clave de Gemini", text: $keyInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85))
                        )
                    Button {
                        saveKey()
                    } label: {
                        Text("Guardar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(Capsule().fill(Color.accentScheme(scheme)))
                    }
                    .buttonStyle(SilentButtonStyle())
                }
                Text(Gemini.lastModel.isEmpty
                     ? "El modelo que responda aparecerá junto al resultado."
                     : "Último modelo que respondió: \(Gemini.lastModel)")
                    .font(.caption)
                    .foregroundStyle(Color.ink2(scheme))
                if !keyState.isEmpty {
                    Text(keyState)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(keyState.contains("✓") ? Color.accentScheme(scheme) : Color.qvRed)
                } else {
                    Text(store.geminiKey.isEmpty
                         ? "Sin clave: la búsqueda por descripción está apagada"
                         : "Clave guardada ✓")
                        .font(.caption)
                        .foregroundStyle(Color.ink2(scheme))
                }
                if !store.geminiKey.isEmpty {
                    Button("Quitar la clave", role: .destructive) {
                        store.geminiKey = ""
                        keyInput = ""
                        keyState = "Sin clave: la búsqueda por descripción está apagada"
                    }
                    .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { keyInput = store.geminiKey }
    }

    private func saveKey() {
        let v = keyInput.trimmingCharacters(in: .whitespaces)
        store.geminiKey = v
        if v.isEmpty {
            keyState = "Sin clave: la búsqueda por descripción está apagada"
            return
        }
        checkingKey = true
        keyState = "Comprobando…"
        Task {
            do {
                _ = try await Gemini.availableModels(key: v)
                keyState = "Clave guardada · acceso a modelos comprobado ✓"
            } catch let e as AIError {
                keyState = e.message
            } catch {
                keyState = "No se pudo comprobar la clave. Revisa tu conexión."
            }
            checkingKey = false
        }
    }

    // MARK: Datos y atribución

    private var datosCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Datos")
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.ink2(scheme))
                Text("Fichas, carátulas, plataformas y nota IMDb: JustWatch · Tus vistas y pendientes se guardan solo en este dispositivo.")
                    .font(.caption)
                    .foregroundStyle(Color.ink2(scheme))
                Text("Privacidad 🔒")
                    .font(.headline)
                    .foregroundStyle(Color.ink(scheme))
                Text("Sin cuentas, sin servidores propios, sin analítica ni rastreo. La clave de Gemini viaja únicamente a Google cuando usas la búsqueda por descripción. El texto que pegas de Gemini no sale de tu iPhone: solo se consultan los títulos detectados.")
                    .font(.caption)
                    .foregroundStyle(Color.ink2(scheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Importar / exportar

    private var backupCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tu lista")
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.ink2(scheme))
                HStack(spacing: 8) {
                    Button {
                        exportDoc = QVJSONDocument(data: store.exportData())
                        showExporter = true
                    } label: {
                        Text("Exportar")
                    }
                    .buttonStyle(PrimaryButtonStyle(prominent: false))
                    Button {
                        showImporter = true
                    } label: {
                        Text("Importar")
                    }
                    .buttonStyle(PrimaryButtonStyle(prominent: false))
                }
                Button {
                    guard !importingSeed else { return }
                    importingSeed = true
                    Task {
                        do {
                            let n = try await store.importSeedFromWeb()
                            ToastCenter.shared.show(n > 0 ? "Lista importada: \(n) títulos ✓" : "Tu lista ya estaba importada ✓")
                        } catch {
                            ToastCenter.shared.show("No se pudo importar ahora. Revisa tu conexión.")
                        }
                        importingSeed = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if importingSeed {
                            ProgressView()
                        }
                        Text(importingSeed ? "Importando…" : "Traer mi lista de la web 🍿")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                Text("Trae las películas y series que ya tenías en la app web (que-ver.pages.dev). Lo que hayas marcado como pendiente o visto después en la web se repite aquí con un toque en cada ficha.")
                    .font(.caption)
                    .foregroundStyle(Color.ink2(scheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Documento JSON para exportar

struct QVJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
