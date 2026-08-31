import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.035, green: 0.035, blue: 0.04)
    static let panel = Color(red: 0.075, green: 0.075, blue: 0.085)
    static let raisedPanel = Color(red: 0.105, green: 0.105, blue: 0.115)
    static let border = Color.white.opacity(0.12)
    static let orange = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let subdued = Color.white.opacity(0.62)
}

struct PanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
    }
}

extension View {
    func appPanel() -> some View {
        modifier(PanelModifier())
    }
}
