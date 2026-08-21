import SwiftUI

@MainActor
final class LaunchOverlayModel: ObservableObject {
    @Published var opacity: Double = 0
    @Published var logoScale: Double = 0.95
    @Published var logoOpacity: Double = 0
    @Published var logoOffsetY: Double = 0
    @Published var logoOffsetX: Double = 0
    
    @Published var targetOffsetX: Double = 0
    @Published var targetOffsetY: Double = -480
    
    @Published var sparkleScale: Double = 0.2
    @Published var sparkleOpacity: Double = 0
    @Published var edgeGlowOpacity: Double = 0.45
}

struct LaunchOverlayView: View {
    @ObservedObject var model: LaunchOverlayModel

    // Mild Red Edge Glow & Sparkle Palette
    private static let mildRed = Color(red: 0.95, green: 0.25, blue: 0.32)
    private static let mildCoralRed = Color(red: 0.98, green: 0.38, blue: 0.35)
    private static let softCrimson = Color(red: 0.88, green: 0.20, blue: 0.28)
    private static let warmRose = Color(red: 1.00, green: 0.42, blue: 0.40)

    private static let sideDepth: Double = 0.018
    private static let topDepth: Double = 0.020

    private var appIconImage: NSImage {
        if let icon = Bundle.main.image(forResource: "launch_transparent") ?? Bundle.main.image(forResource: "MOOZIAC") ?? Bundle.main.image(forResource: "MOOZIAC_transparent") {
            return icon
        }
        return NSImage(systemSymbolName: "music.note.house.fill", accessibilityDescription: "Mooziac") ?? NSImage()
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                // 1. Delicate Mild Red Ambient Radial Overlay Splash
                if model.edgeGlowOpacity > 0.01 {
                    RadialGradient(
                        stops: [
                            .init(color: Self.mildRed.opacity(0.05 * (model.edgeGlowOpacity / 0.45)), location: 0.0),
                            .init(color: Self.mildCoralRed.opacity(0.03 * (model.edgeGlowOpacity / 0.45)), location: 0.50),
                            .init(color: Color.clear, location: 0.85)
                        ],
                        center: .center,
                        startRadius: 50,
                        endRadius: min(size.width, size.height) * 0.50
                    )

                    // 2. Ultra-Thin Screen Edge Ribbon Splash
                    siriEdgeRibbon(.top, in: size)
                    siriEdgeRibbon(.bottom, in: size)
                    siriEdgeRibbon(.leading, in: size)
                    siriEdgeRibbon(.trailing, in: size)
                }

                // 3. Magical Swoosh Sparkle Burst Ring (at EXACT Status Bar Item location!)
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Self.mildRed, Self.warmRose, Self.mildCoralRed],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3.5
                    )
                    .frame(width: 34, height: 34)
                    .scaleEffect(model.sparkleScale)
                    .opacity(model.sparkleOpacity)
                    .offset(x: model.targetOffsetX, y: model.targetOffsetY)
                    .blur(radius: 1.2)

                // 4. Flying & Shrinking Hero Music App Icon
                Image(nsImage: appIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 380, height: 380)
                    .scaleEffect(model.logoScale)
                    .offset(x: model.logoOffsetX, y: model.logoOffsetY)
                    .opacity(model.logoOpacity)
                    .shadow(color: Self.mildRed.opacity(0.35 * model.logoOpacity), radius: 16 * max(0.1, model.logoScale), x: 0, y: 4)
            }
            .frame(width: size.width, height: size.height)
        }
        .opacity(model.opacity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func siriEdgeRibbon(_ edge: Edge, in size: CGSize) -> some View {
        let isHorizontal = edge == .leading || edge == .trailing
        let depth = isHorizontal
            ? size.width * Self.sideDepth
            : size.height * Self.topDepth

        let gradientColors: [Color] = edge == .top || edge == .leading
            ? [Self.mildRed, Self.mildCoralRed, Self.softCrimson, Self.warmRose]
            : [Self.warmRose, Self.softCrimson, Self.mildCoralRed, Self.mildRed]

        let gradient = LinearGradient(
            stops: [
                .init(color: gradientColors[0].opacity(model.edgeGlowOpacity), location: 0.0),
                .init(color: gradientColors[1].opacity(model.edgeGlowOpacity * 0.70), location: 0.35),
                .init(color: gradientColors[2].opacity(model.edgeGlowOpacity * 0.30), location: 0.70),
                .init(color: Color.clear, location: 1.0),
            ],
            startPoint: startPoint(for: edge),
            endPoint: endPoint(for: edge)
        )

        return gradient
            .frame(
                width: isHorizontal ? depth : size.width,
                height: isHorizontal ? size.height : depth
            )
            .blur(radius: 25)
            .frame(width: size.width, height: size.height, alignment: alignment(for: edge))
    }

    private func startPoint(for edge: Edge) -> UnitPoint {
        switch edge {
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }

    private func endPoint(for edge: Edge) -> UnitPoint {
        switch edge {
        case .top: return .bottom
        case .bottom: return .top
        case .leading: return .trailing
        case .trailing: return .leading
        }
    }

    private func alignment(for edge: Edge) -> Alignment {
        switch edge {
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }
}
