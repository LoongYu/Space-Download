import SwiftUI

struct ContentView: View {
    var body: some View {
        MainDownloadView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }
}
