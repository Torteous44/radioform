import SwiftUI

/// Plain white background for the onboarding window
struct VintagePaperBackground: View {
    var body: some View {
        Color.white
    }
}

/// View modifier to apply white background
struct VintagePaperBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(VintagePaperBackground())
    }
}

extension View {
    func vintagePaperBackground() -> some View {
        modifier(VintagePaperBackgroundModifier())
    }
}

#Preview {
    VintagePaperBackground()
        .frame(width: 600, height: 500)
}
