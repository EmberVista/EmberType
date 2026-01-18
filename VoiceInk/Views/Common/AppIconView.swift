import SwiftUI

struct AppIconView: View {
    var body: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(DesignTokens.accent.opacity(0.15))
                .frame(width: 200, height: 200)
                .blur(radius: 40)

            // Text logo
            Image("EmberTypeLogo")
                .renderingMode(.original)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .aspectRatio(contentMode: .fit)
                .frame(width: 280)
                .shadow(color: DesignTokens.accent.opacity(0.4), radius: 20)
        }
    }
} 