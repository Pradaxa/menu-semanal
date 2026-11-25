import ActivityKit
import Foundation

/// Arranca, actualiza y cierra la Live Activity del progreso de generación con IA.
/// Todo local (sin APNs): vive mientras la app está en primer plano o en los ~30 s
/// de vida extra en segundo plano. Si el usuario las desactiva en Ajustes, no falla.
enum LiveProgress {
    private static var activity: Activity<GenActivityAttributes>?

    static func start() {
        endImmediate()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = GenActivityAttributes.ContentState(progress: 0.05, stage: "")
        let content = ActivityContent(state: state, staleDate: nil)
        activity = try? Activity<GenActivityAttributes>.request(
            attributes: GenActivityAttributes(title: "Menú semanal"),
            content: content,
            pushType: nil
        )
    }

    static func update(_ progress: Double, _ stage: String) {
        guard let activity else { return }
        let state = GenActivityAttributes.ContentState(progress: progress, stage: stage)
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    /// Cierre con éxito: queda "Menú listo" fija hasta que el usuario la quite él.
    static func finish() {
        guard let activity else { return }
        self.activity = nil
        let state = GenActivityAttributes.ContentState(progress: 1, stage: "Menú listo")
        Task {
            // .default: sale de la isla pero se queda en la pantalla de bloqueo
            // hasta que él la descarte (el sistema la limpia a las 4 h si no).
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .default
            )
        }
    }

    /// Cierre por error o generación interrumpida: se retira al momento.
    static func cancel() {
        endImmediate()
    }

    private static func endImmediate() {
        guard let activity else { return }
        self.activity = nil
        let state = activity.content.state
        Task {
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }
}
