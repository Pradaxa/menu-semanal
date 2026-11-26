import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

/// Live Activity de la generación con IA: barra de progreso + un texto, altura mínima.
/// Sin APNs: la app la arranca, actualiza y cierra localmente mientras genera.
struct GenLiveActivity: Widget {
    @ViewBuilder private static var appIcon: some View {
        if let icon = UIImage(named: "icon-live") {
            Image(uiImage: icon)
                .resizable()
                .frame(width: 16, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 16 * 0.2237, style: .continuous))
        } else {
            Image(systemName: "fork.knife")
                .font(.caption2)
        }
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GenActivityAttributes.self) { context in
            GenActivityBanner(progress: context.state.progress, stage: context.state.stage)
                .activityBackgroundTint(Color(uiColor: UIColor { t in
                    t.userInterfaceStyle == .dark
                        ? UIColor(red: 0.06, green: 0.27, blue: 0.20, alpha: 1)
                        : UIColor(red: 0.74, green: 0.93, blue: 0.84, alpha: 1)
                }))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    GenActivityBanner(progress: context.state.progress, stage: context.state.stage)
                }
            } compactLeading: {
                Text("\(Int((context.state.progress * 100).rounded()))%")
                    .font(.caption2.bold().monospacedDigit())
            } compactTrailing: {
                GenLiveActivity.appIcon
            } minimal: {
                GenLiveActivity.appIcon
            }
        }
    }
}
