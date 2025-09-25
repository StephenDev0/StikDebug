//
//  AppTheme.swift
//  StikJIT
//
//  Created by Assistant on 9/12/25.
//

import SwiftUI

// MARK: - AppTheme model

enum AppTheme: String, CaseIterable, Identifiable {
    case system            // balanced default gradient
    case darkStatic        // deep charcoal blend
    case neonAnimated      // neon pulse
    case blobs             // vibrant haze
    case particles         // subtle celestial particles
    case aurora            // shifting aurora lights
    case sunset            // warm sunset glow
    case ocean             // tranquil ocean blues
    case forest            // lush forest canopy
    case midnight          // midnight horizon
    case cyberwave         // synthwave inspired
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system:       return "Default"
        case .darkStatic:   return "Obsidian"
        case .neonAnimated: return "Neon Pulse"
        case .blobs:        return "Haze"
        case .particles:    return "Stardust"
        case .aurora:       return "Aurora"
        case .sunset:       return "Sunset"
        case .ocean:        return "Ocean"
        case .forest:       return "Forest"
        case .midnight:     return "Midnight"
        case .cyberwave:    return "Cyberwave"
        }
    }
    
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .sunset, .forest:
            return nil
        case .darkStatic, .neonAnimated, .blobs, .particles, .aurora, .ocean, .midnight, .cyberwave:
            return .dark
        }
    }
    
    var backgroundStyle: BackgroundStyle {
        switch self {
        case .system:
            return .adaptiveGradient(light: Palette.systemLightGradient,
                                     dark: Palette.systemDarkGradient)
        case .darkStatic:
            return .staticGradient(colors: Palette.obsidianGradient)
        case .neonAnimated:
            return .animatedGradient(colors: Palette.neon, speed: 0.10)
        case .blobs:
            return .blobs(colors: Palette.hazeBlobs, background: Palette.hazeBackground)
        case .particles:
            return .particles(particle: Palette.stardustParticle, background: Palette.stardustBackground)
        case .aurora:
            return .animatedGradient(colors: Palette.aurora, speed: 0.08)
        case .sunset:
            return .staticGradient(colors: Palette.sunset)
        case .ocean:
            return .animatedGradient(colors: Palette.ocean, speed: 0.06)
        case .forest:
            return .staticGradient(colors: Palette.forest)
        case .midnight:
            return .particles(particle: Palette.midnightParticle, background: Palette.midnightBackground)
        case .cyberwave:
            return .blobs(colors: Palette.cyberwaveBlobs, background: Palette.cyberwaveBackground)
        }
    }
}

// MARK: - Background styles and factory

enum BackgroundStyle: Equatable {
    case staticGradient(colors: [Color])
    case animatedGradient(colors: [Color], speed: Double)
    case blobs(colors: [Color], background: [Color])
    case particles(particle: Color, background: [Color])
    case customGradient(colors: [Color])
    case adaptiveGradient(light: [Color], dark: [Color])
}

private struct Palette {
    static let defaultGradient = hexColors("#1C1F3A", "#3E4C7C", "#1F1C2C")
    static let systemLightGradient = hexColors("#F6F8FF", "#E3ECFF", "#F0F4FF")
    static let systemDarkGradient = obsidianGradient
    static let obsidianGradient = hexColors("#000000", "#1C1C1C", "#262626")
    static let neon = hexColors("#00F5A0", "#00D9F5", "#C96BFF")
    static let hazeBlobs = hexColors("#FF8BA7", "#A98BFF", "#70C8FF", "#67FFDA")
    static let hazeBackground = hexColors("#141321", "#1E1C2A")
    static let stardustParticle = Color(hex: "#9BD4FF") ?? .white
    static let stardustBackground = hexColors("#090A1A", "#1C1F3A")
    static let aurora = hexColors("#0BA360", "#3CBA92", "#8241FF")
    static let sunset = hexColors("#FF5F6D", "#FFC371", "#FF9966")
    static let ocean = hexColors("#0093E9", "#80D0C7", "#13547A")
    static let forest = hexColors("#2F7336", "#AA3A38", "#052E03")
    static let midnightParticle = Color(hex: "#9F9FFF") ?? .white
    static let midnightBackground = hexColors("#0F2027", "#203A43", "#2C5364")
    static let cyberwaveBlobs = hexColors("#FF0080", "#7928CA", "#2A2A72", "#00F0FF")
    static let cyberwaveBackground = hexColors("#08001A", "#110032")

    static func hexColors(_ hexes: String...) -> [Color] {
        hexes.compactMap { Color(hex: $0) }
    }
}

// MARK: - Helpers

private func staticGradientView(colors: [Color]) -> some View {
    LinearGradient(
        gradient: Gradient(colors: colors.ensureMinimumCount()),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct ThemedBackground: View {
    let style: BackgroundStyle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            switch style {
            case .staticGradient(let colors):
                staticGradientView(colors: colors)
                    .ignoresSafeArea()
            case .animatedGradient(let colors, let speed):
                if reduceMotion {
                    staticGradientView(colors: colors)
                        .ignoresSafeArea()
                } else {
                    AnimatedGradientBackground(colors: colors, speed: speed)
                }
            case .blobs(let colors, let background):
                if reduceMotion {
                    staticGradientView(colors: background.isEmpty ? colors : background)
                        .ignoresSafeArea()
                } else {
                    BlobBackground(blobColors: colors.ensureMinimumCount(), backgroundColors: background.ensureMinimumCount())
                }
            case .particles(let particle, let background):
                if reduceMotion {
                    staticGradientView(colors: background.ensureMinimumCount())
                        .ignoresSafeArea()
                } else {
                    ParticleFieldBackground(particleColor: particle, backgroundColors: background.ensureMinimumCount())
                }
            case .customGradient(let colors):
                staticGradientView(colors: colors)
                    .ignoresSafeArea()
            case .adaptiveGradient(let light, let dark):
                let colors = colorScheme == .dark ? dark : light
                staticGradientView(colors: colors)
                    .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Background container to use at app root

struct BackgroundContainer<Content: View>: View {
    @AppStorage("appTheme") private var rawTheme: String = AppTheme.system.rawValue
    @Environment(\.themeExpansionManager) private var themeExpansion
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    private var backgroundStyle: BackgroundStyle {
        themeExpansion?.backgroundStyle(for: rawTheme) ?? AppTheme.system.backgroundStyle
    }
    
    private var preferredScheme: ColorScheme? {
        themeExpansion?.preferredColorScheme(for: rawTheme)
    }
    
    var body: some View {
        ZStack {
            ThemedBackground(style: backgroundStyle)
                .ignoresSafeArea()
            content
        }
        .preferredColorScheme(preferredScheme)
    }
}

// MARK: - Animated backgrounds

private struct AnimatedGradientBackground: View {
    let colors: [Color]
    let speed: Double
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let phase = now * speed
            let rotation = Angle(degrees: phase.truncatingRemainder(dividingBy: 360) * 45)
            let gradientColors = colors.ensureMinimumCount()

            Rectangle()
                .fill(
                    AngularGradient(colors: gradientColors + [gradientColors.first!], center: .center, angle: .degrees(0))
                )
                .hueRotation(.degrees(phase.truncatingRemainder(dividingBy: 360) * 30))
                .rotationEffect(rotation)
                .scaleEffect(1.2)
                .ignoresSafeArea()
                .overlay(
                    LinearGradient(colors: [.black.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                )
        }
    }
}

private struct BlobBackground: View {
    let blobColors: [Color]
    let backgroundColors: [Color]
    @State private var t: CGFloat = 0
    
    var body: some View {
        Canvas { ctx, size in
            let blobs = max(blobColors.count, 4)
            let radius = min(size.width, size.height) * 0.45
            
            for i in 0..<blobs {
                let color = blobColors[i % blobColors.count].opacity(0.32)
                let p = CGFloat(i) / CGFloat(blobs)
                let angle = t * (0.45 + 0.08 * CGFloat(i)) + p * .pi * 2
                let r = radius * (0.38 + 0.18 * sin(t + CGFloat(i)))
                
                let x = size.width  * 0.5 + cos(angle) * r
                let y = size.height * 0.5 + sin(angle * 0.92) * r * 0.72
                
                var path = Path()
                path.addEllipse(in: CGRect(x: x - 140, y: y - 140, width: 280, height: 280))
                
                ctx.addFilter(.blur(radius: 42))
                ctx.fill(path, with: .color(color))
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: backgroundColors.ensureMinimumCount()),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                t = .pi * 2
            }
        }
    }
}

private struct ParticleFieldBackground: View {
    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGVector
        var size: CGFloat
        var opacity: Double
    }
    
    let particleColor: Color
    let backgroundColors: [Color]
    @State private var particles: [Particle] = []
    private let count = 120
    
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { _ in
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: backgroundColors.ensureMinimumCount()),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    Canvas { ctx, size in
                        for p in particles {
                            var circle = Path(ellipseIn: CGRect(x: p.position.x,
                                                                y: p.position.y,
                                                                width: p.size,
                                                                height: p.size))
                            ctx.addFilter(.blur(radius: 1.1))
                            ctx.opacity = p.opacity
                            ctx.fill(circle, with: .color(particleColor.opacity(0.9)))
                        }
                    }
                }
                .onAppear {
                    if particles.isEmpty {
                        particles = (0..<count).map { _ in
                            Particle(
                                position: CGPoint(x: .random(in: 0...geo.size.width),
                                                  y: .random(in: 0...geo.size.height)),
                                velocity: CGVector(dx: .random(in: -0.28...0.28),
                                                   dy: .random(in: -0.28...0.28)),
                                size: .random(in: 1.6...3.8),
                                opacity: .random(in: 0.20...0.45)
                            )
                        }
                    }
                }
                .onChange(of: geo.size) { _, newSize in
                    particles = particles.map { p in
                        var np = p
                        np.position.x = min(max(0, np.position.x), newSize.width)
                        np.position.y = min(max(0, np.position.y), newSize.height)
                        return np
                    }
                }
                .task {
                    while true {
                        try? await Task.sleep(nanoseconds: 16_000_000)
                        var next = particles
                        for i in next.indices {
                            var p = next[i]
                            p.position.x += p.velocity.dx
                            p.position.y += p.velocity.dy
                            
                            if p.position.x < 0 { p.position.x = geo.size.width }
                            if p.position.x > geo.size.width { p.position.x = 0 }
                            if p.position.y < 0 { p.position.y = geo.size.height }
                            if p.position.y > geo.size.height { p.position.y = 0 }
                            
                            next[i] = p
                        }
                        particles = next
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

private extension Array where Element == Color {
    func ensureMinimumCount() -> [Color] {
        if isEmpty { return [.blue, .purple] }
        if count == 1 { return [self[0], self[0].opacity(0.6)] }
        return self
    }
}
