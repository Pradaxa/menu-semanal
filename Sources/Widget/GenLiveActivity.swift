import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity de la generación con IA: barra de progreso + un texto, altura mínima.
/// Sin APNs: la app la arranca, actualiza y cierra localmente mientras genera.
struct GenLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GenActivityAttributes.self) { context in
            GenActivityBanner(progress: context.state.progress, stage: context.state.stage)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    GenActivityBanner(progress: context.state.progress, stage: context.state.stage)
                }
            } compactLeading: {
                Text("\(Int((context.state.progress * 100).rounded()))%")
                    .font(.caption2.bold().monospacedDigit())
            } compactTrailing: {
                Image(systemName: "fork.knife")
                    .font(.caption2)
            } minimal: {
                Image(systemName: "fork.knife")
                    .font(.caption2)
            }
        }
    }
}
