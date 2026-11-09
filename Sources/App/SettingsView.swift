import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

// MARK: - Tab Ajustes

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDoc: JSONDocument?
    @State private var notice: String?
    @State private var testing = false
    @State private var testResult: String?
    @State private var confirmResetLearning = false

    private var isDark: Bool {
        store.darkOverride ?? (scheme == .dark)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    themeCard
                    learningCard
                    backupCard
                    geminiCard
                    infoCard
                    diagnosticsCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Aviso", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("Vale", role: .cancel) {}
            } message: {
                Text(notice ?? "")
            }
        }
    }

    private var themeCard: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Modo oscuro 🌗")
                        .font(.headline)
                    Text(store.darkOverride == nil
                         ? "Siguiendo el modo del iPhone"
                         : (store.darkOverride! ? "Siempre oscuro" : "Siempre claro"))
                        .font(.caption)
                        .foregroundStyle(Color.ink2(scheme))
                }
                Spacer()
                SunMoonToggle(isDark: Binding(
                    get: { isDark },
                    set: { store.darkOverride = $0 }
                ))
            }
            if store.darkOverride != nil {
                Button("Usar el modo del iPhone") {
                    store.darkOverride = nil
                }
                .font(.callout)
                .tint(Color.tealScheme(scheme))
            }
        }
    }

    private var learningCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Lo que he aprendido 🧠")
                    .font(.headline)
                let l = store.learning
                if l.weeks == 0 && l.kept.isEmpty && l.added.isEmpty && l.removed.isEmpty {
                    Text("Aún no he aprendido nada. Confirma menús y ajusta platos a tu gusto y los iré teniendo en cuenta.")
                        .font(.callout)
                        .foregroundStyle(Color.ink2(scheme))
                } else {
                    Text("Basado en \(l.weeks) \(l.weeks == 1 ? "menú confirmado" : "menús confirmados") y tus cambios. Los platos que dejas o eliges tú salen más; los que cambias, menos.")
                        .font(.callout)
                        .foregroundStyle(Color.ink2(scheme))
                    Button("Olvidar lo aprendido", role: .destructive) { confirmResetLearning = true }
                        .font(.callout)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .confirmationDialog("¿Olvidar todo lo aprendido? Los menús y el historial no se tocan.",
                            isPresented: $confirmResetLearning, titleVisibility: .visible) {
            Button("Olvidar", role: .destructive) { store.resetLearning() }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var backupCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Copia de seguridad 💾")
                    .font(.headline)
                Text("Guarda tus platos, menús, historial, aprendizaje y compra. La clave de Gemini no se incluye. La copia es manual: repítela después de cambios importantes.")
                    .font(.callout)
                    .foregroundStyle(Color.ink2(scheme))
                HStack(spacing: 10) {
                    Button {
                        do {
                            exportDoc = try JSONDocument(data: store.exportData())
                            showExporter = true
                        } catch {
                            notice = "No se pudo preparar la copia."
                        }
                    } label: {
                        Label("Exportar copia", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.tealScheme(scheme))

                    Button {
                        showImporter = true
                    } label: {
                        Label("Importar copia", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.tealScheme(scheme))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fileExporter(isPresented: $showExporter, document: exportDoc, contentType: .json,
                      defaultFilename: "menus-copia-\(String(Engine.isoNow().prefix(10)))") { _ in }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                let ok = url.startAccessingSecurityScopedResource()
                defer { if ok { url.stopAccessingSecurityScopedResource() } }
                do {
                    let data = try Data(contentsOf: url)
                    try store.importData(data)
                    notice = "Copia importada. Tus platos, menús y compra ya están aquí."
                } catch {
                    notice = error.localizedDescription
                }
            case .failure:
                break
            }
        }
    }

    private var geminiCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Clave de Gemini (IA) ✨")
                    .font(.headline)
                Text("Solo se guarda en este iPhone. Sin clave, los menús se generan con tus reglas, que ya funcionan muy bien.")
                    .font(.callout)
                    .foregroundStyle(Color.ink2(scheme))
                Text("IA opcional con tu propia clave. Cada usuario responde del uso de su cuenta y del cumplimiento de los términos de Google. Añadir una clave no garantiza que el uso esté permitido ni sea gratuito. Google exige servicios de pago para clientes API ofrecidos en el EEE, Suiza y Reino Unido y puede restringir el acceso. Esta app no activa facturación ni incluye una clave compartida.")
                    .font(.caption)
                    .foregroundStyle(Color.ink2(scheme))
                Link("Leer los términos de Gemini API", destination: URL(string: "https://aistudio.google.com/docs/terms")!)
                    .font(.caption)
                SecureField("Pega tu clave", text: $store.geminiKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                HStack {
                    Button {
                        testing = true
                        testResult = nil
                        let key = store.geminiKey
                        DispatchQueue.global(qos: .userInitiated).async {
                            do {
                                let report = try Gemini.testKey(key)
                                DispatchQueue.main.async { testResult = report; testing = false }
                            } catch {
                                DispatchQueue.main.async { testResult = error.localizedDescription; testing = false }
                            }
                        }
                    } label: {
                        HStack {
                            if testing { ProgressView().scaleEffect(0.8) }
                            Text("Probar clave")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.tealScheme(scheme))
                    .disabled(testing || store.geminiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    if !store.geminiKey.isEmpty {
                        Button("Quitar", role: .destructive) { store.geminiKey = "" }
                            .font(.callout)
                    }
                }
                if let testResult = testResult {
                    Text(testResult)
                        .font(.caption)
                        .foregroundStyle(Color.ink2(scheme))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var diagnosticsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Diagnóstico del widget 🛠️")
                        .font(.headline)
                    Spacer()
                    Button("Actualizar widget") { WidgetCenter.shared.reloadAllTimelines() }
                        .font(.caption)
                }
                Text("Grupo app: \(GroupDiagnostics.appResolved)")
                Text("Grupo declarado (app): \(GroupDiagnostics.appDeclared.isEmpty ? "—" : GroupDiagnostics.appDeclared.joined(separator: ", "))")
                Text("Grupo declarado (widget): \(GroupDiagnostics.widgetDeclared.isEmpty ? "—" : GroupDiagnostics.widgetDeclared.joined(separator: ", "))")
                Text("Almacén compartido: \(GroupDiagnostics.storeIsShared ? "sí" : "no (respaldo local)")")
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color.ink2(scheme))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var infoCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Privacidad 🔒")
                    .font(.headline)
                Text("Tus datos se guardan en tu iPhone. Sin analítica ni rastreo. Si activas la IA con tu clave, se envían a Google el nombre del plato o los datos de platos, turnos y preferencias necesarios para generar el menú. Probar la clave también consulta Google. Sin clave no se llama a Gemini. Consulta la política del proyecto y la de Google.")
                    .font(.callout)
                    .foregroundStyle(Color.ink2(scheme))
                Text("Menú · versión \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                    .font(.caption)
                    .foregroundStyle(Color.ink2(scheme).opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Documento JSON para exportar

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
