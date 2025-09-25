//  DisplayView.swift
//  StikJIT
//
//  Created by neoarz on 4/9/25.

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Accent Color Picker (Glassy style)
struct AccentColorPicker: View {
    @Binding var selectedColor: Color
    
    let colors: [Color] = [
        .blue,
        .init(hex: "#7FFFD4")!,
        .init(hex: "#50C878")!,
        .red,
        .init(hex: "#6A5ACD")!,
        .init(hex: "#DA70D6")!,
        .white,
        .black
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Accent Color")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 12), count: 9), spacing: 12) {
                ForEach(colors, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .overlay(
                            Circle().stroke(selectedColor == color ? Color.primary : .clear, lineWidth: 2)
                        )
                        .onTapGesture {
                            selectedColor = color
                        }
                }
                
                ColorPicker("", selection: $selectedColor)
                    .labelsHidden()
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .clipShape(Circle())
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Display Settings View
struct DisplayView: View {
    @AppStorage("username") private var username = "User"
    @AppStorage("customAccentColor") private var customAccentColorHex: String = ""
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage("loadAppIconsOnJIT") private var loadAppIconsOnJIT = true
    @State private var selectedAccentColor: Color = .blue
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeExpansionManager) private var themeExpansionOptional

    @State private var justSaved = false
    @State private var showingCreateCustomTheme = false
    @State private var editingCustomTheme: CustomTheme?

    private var themeExpansion: ThemeExpansionManager? { themeExpansionOptional }

    private var hasThemeExpansion: Bool { themeExpansion?.hasThemeExpansion == true }

    private var accentColor: Color {
        themeExpansion?.resolvedAccentColor(from: customAccentColorHex) ?? .blue
    }

    private var tintColor: Color {
        hasThemeExpansion ? selectedAccentColor : .blue
    }

    private var selectedThemeIdentifier: String { appThemeRaw }

    private var selectedBuiltInTheme: AppTheme? {
        AppTheme(rawValue: selectedThemeIdentifier)
    }

    private var selectedCustomTheme: CustomTheme? {
        themeExpansion?.customTheme(for: selectedThemeIdentifier)
    }

    private var backgroundStyle: BackgroundStyle {
        themeExpansion?.backgroundStyle(for: selectedThemeIdentifier) ?? AppTheme.system.backgroundStyle
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground(style: backgroundStyle)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        usernameCard
                        if hasThemeExpansion {
                            accentCard
                            themeCard
                            customThemesSection
                        } else {
                            // Accent preview remains above
                            accentPreview
                            
                            // Built-in + Custom themes previews with paywall centered on top
                            ZStack(alignment: .center) {
                                VStack(spacing: 20) {
                                    themePreview
                                    customThemesPreview
                                }
                                .zIndex(0)
                                
                                themeExpansionUpsellCard
                                    .frame(maxWidth: .infinity) // match other cards’ width
                                    .zIndex(1)
                            }
                        }
                        jitOptionsCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 30)
                }
                
                if justSaved {
                    VStack {
                        Spacer()
                        Text("Saved")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 3)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 30)
                    }
                    .animation(.easeInOut(duration: 0.25), value: justSaved)
                }
            }
            .navigationTitle("Display")
            .onAppear {
                if !hasThemeExpansion, let manager = themeExpansion, manager.isCustomThemeIdentifier(appThemeRaw) {
                    appThemeRaw = AppTheme.system.rawValue
                }
                loadCustomAccentColor()
                applyThemePreferences()
            }
            .onChange(of: appThemeRaw) { _, newValue in
                guard hasThemeExpansion, let manager = themeExpansion else { return }
                if manager.isCustomThemeIdentifier(newValue), manager.customTheme(for: newValue) == nil {
                    appThemeRaw = AppTheme.system.rawValue
                }
                applyThemePreferences()
            }
            .onChange(of: themeExpansion?.hasThemeExpansion ?? false) { unlocked in
                if unlocked {
                    loadCustomAccentColor()
                    applyThemePreferences()
                } else {
                    selectedAccentColor = .blue
                    appThemeRaw = AppTheme.system.rawValue
                    applyThemePreferences()
                }
            }
        }
        .tint(tintColor)
        .sheet(isPresented: $showingCreateCustomTheme) {
            CustomThemeEditorView(initialTheme: nil) { newTheme in
                themeExpansion?.upsert(customTheme: newTheme)
                if let manager = themeExpansion {
                    appThemeRaw = manager.customThemeIdentifier(for: newTheme)
                }
                applyThemePreferences()
                showSavedToast()
            }
        }
        .sheet(item: $editingCustomTheme) { theme in
            CustomThemeEditorView(initialTheme: theme,
                                  onSave: { updated in
                                      themeExpansion?.upsert(customTheme: updated)
                                      if let manager = themeExpansion {
                                          appThemeRaw = manager.customThemeIdentifier(for: updated)
                                      }
                                      applyThemePreferences()
                                      showSavedToast()
                                  },
                                  onDelete: {
                                      if let manager = themeExpansion {
                                          manager.delete(customTheme: theme)
                                          if manager.customThemeIdentifier(for: theme) == appThemeRaw {
                                              appThemeRaw = AppTheme.system.rawValue
                                              applyThemePreferences()
                                          }
                                      }
                                  })
        }
    }
    
    // MARK: - Cards
    
    private var usernameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Username")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack {
                TextField("Username", text: $username)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(.vertical, 8)
                
                if !username.isEmpty {
                    Button(action: {
                        username = ""
                        showSavedToast()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }
    
    private var accentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accent")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            AccentColorPicker(selectedColor: $selectedAccentColor)

            HStack(spacing: 12) {
                Button {
                    if let hex = selectedAccentColor.toHex() {
                        customAccentColorHex = hex
                    } else {
                        customAccentColorHex = ""
                    }
                    showSavedToast()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selectedAccentColor)
                    )
                    .foregroundColor(selectedAccentColor.contrastText())
                }

                Button {
                    customAccentColorHex = ""
                    selectedAccentColor = .blue
                    showSavedToast()
                } label: {
                    HStack {
                        Image(systemName: "arrow.uturn.backward.circle")
                        Text("Reset")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(UIColor.tertiarySystemBackground))
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }

    private var themeExpansionUpsellCard: some View {
        let isAppStore = themeExpansion?.isAppStoreBuild ?? true
        let productLoaded = themeExpansion?.themeExpansionProduct != nil
        return VStack(alignment: .leading, spacing: 14) {
            Text("StikDebug Theme Expansion")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            if !isAppStore {
                Text("Theme Expansion is coming soon on this store.")
                    .font(.body)
                    .foregroundColor(.secondary)
                Text("For now, you can continue using the default theme.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Text("Unlock custom accent colors and dynamic backgrounds with the Theme Expansion.")
                    .font(.body)
                    .foregroundColor(.secondary)

                if let price = themeExpansion?.themeExpansionProduct?.displayPrice {
                    Text("One-time purchase • \(price)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if productLoaded, let manager = themeExpansion {
                    Button {
                        Task { await manager.purchaseThemeExpansion() }
                    } label: {
                        HStack {
                            if manager.isProcessing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            }
                            Text(manager.isProcessing ? "Purchasing…" : "Unlock Theme Expansion")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.blue)
                        )
                        .foregroundColor(Color.blue.contrastText())
                    }
                    .disabled(manager.isProcessing)
                } else if let manager = themeExpansion {
                    Button {
                        Task { await manager.refreshEntitlements() }
                    } label: {
                        HStack {
                            if manager.isProcessing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            }
                            Text(manager.isProcessing ? "Contacting App Store…" : "Try Again")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .disabled(manager.isProcessing)
                }

                if let manager = themeExpansion {
                    Button {
                        Task { await manager.restorePurchases() }
                    } label: {
                        Text("Restore Purchase")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .disabled(manager.isProcessing)
                }

                if let manager = themeExpansion, !productLoaded, manager.lastError == nil {
                    Text(manager.isProcessing ? "Contacting the App Store…" : "Waiting for App Store information.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                if let error = themeExpansion?.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity) // ensure background fills available width
        .background(
            // Slightly thicker material so the upsell stands out over the previews
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        .task {
            if let manager = themeExpansion,
               manager.isAppStoreBuild,
               !manager.isProcessing,
               manager.themeExpansionProduct == nil,
               manager.lastError == nil {
                await manager.refreshEntitlements()
            }
        }
    }
    
    private var jitOptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App List")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Load App Icons", isOn: $loadAppIconsOnJIT)
                    .tint(accentColor)
                
                Text("Disabling this will hide app icons in the app list and may improve performance, while also giving it a more minimalistic look.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }
    
    private var themeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Theme")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Grid of theme previews
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    ThemePreviewCard(style: theme.backgroundStyle,
                                     title: theme.displayName,
                                     selected: selectedBuiltInTheme == theme && selectedCustomTheme == nil,
                                     action: {
                                         guard hasThemeExpansion else { return }
                                         appThemeRaw = theme.rawValue
                                         applyThemePreferences()
                                         showSavedToast()
                                     },
                                     staticPreview: false)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }

    // Static version used in locked preview to avoid background animation cost
    private var themeCardStatic: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Theme")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    ThemePreviewCard(style: theme.backgroundStyle,
                                     title: theme.displayName,
                                     selected: selectedBuiltInTheme == theme && selectedCustomTheme == nil,
                                     action: {},
                                     staticPreview: true)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private var customThemesSection: some View {
        if hasThemeExpansion, let manager = themeExpansion {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Custom Themes")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Button {
                        showingCreateCustomTheme = true
                    } label: {
                        Label("New", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                if manager.customThemes.isEmpty {
                    VStack(spacing: 8) {
                        Text("Create your own themes with custom colors and motion.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        Button(action: { showingCreateCustomTheme = true }) {
                            Text("Create a Custom Theme")
                                .font(.subheadline.weight(.semibold))
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.blue)
                                )
                                .foregroundColor(Color.blue.contrastText())
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(manager.customThemes, id: \.id) { theme in
                            let identifier = manager.customThemeIdentifier(for: theme)
                            ThemePreviewCard(style: manager.backgroundStyle(for: identifier),
                                             title: theme.name,
                                             selected: selectedCustomTheme?.id == theme.id,
                                             action: {
                                                 appThemeRaw = identifier
                                                 applyThemePreferences()
                                                 showSavedToast()
                                             },
                                             staticPreview: false)
                            .contextMenu {
                                Button("Edit") { editingCustomTheme = theme }
                                Button("Delete", role: .destructive) {
                                    manager.delete(customTheme: theme)
                                    let id = manager.customThemeIdentifier(for: theme)
                                    if appThemeRaw == id {
                                        appThemeRaw = AppTheme.system.rawValue
                                        applyThemePreferences()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        }
    }
    
    // MARK: - Helpers
    
    private func loadCustomAccentColor() {
        selectedAccentColor = themeExpansion?.resolvedAccentColor(from: customAccentColorHex) ?? .blue
    }

    private func applyThemePreferences() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        let scheme = themeExpansion?.preferredColorScheme(for: selectedThemeIdentifier)
        switch scheme {
        case .some(.dark):
            window.overrideUserInterfaceStyle = .dark
        case .some(.light):
            window.overrideUserInterfaceStyle = .light
        default:
            window.overrideUserInterfaceStyle = .unspecified
        }
    }
    
    private func showSavedToast() {
        withAnimation { justSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation { justSaved = false }
        }
    }

    // MARK: - Paywall previews (optimized look, non-interactive)

    private func lockedPreview<Content: View>(_ content: Content) -> some View {
        content
            // Hardware-optimized blur via system material over the content
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.4) // more transparent blur for a stronger preview
            )
            // Slight dim to improve contrast and preserve the “locked” feel
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.03)) // lighter dim for more visibility
            )
            .overlay(alignment: .topLeading) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                    Text("Preview")
                        .fontWeight(.semibold)
                }
                .font(.caption2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                .padding(12)
            }
            .compositingGroup() // flatten for better GPU compositing
            .allowsHitTesting(false)
    }

    // Use static theme grid inside the locked preview to avoid animation cost
    private var accentPreview: some View { lockedPreview(accentCard) }
    private var themePreview: some View { lockedPreview(themeCardStatic) }
    
    private var customThemesPreview: some View {
        lockedPreview(customThemesPreviewCard)
    }
    
    private var customThemesPreviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Custom Themes")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
                Label("New", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.6)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ThemePreviewCard(
                    style: .customGradient(colors: [Color(hex: "#3E4C7C") ?? .indigo,
                                                    Color(hex: "#1C1F3A") ?? .blue]),
                    title: "Midnight Fade",
                    selected: false,
                    action: {},
                    staticPreview: true
                )
                ThemePreviewCard(
                    style: .customGradient(colors: [Color(hex: "#00F5A0") ?? .green,
                                                    Color(hex: "#00D9F5") ?? .cyan,
                                                    Color(hex: "#C96BFF") ?? .purple]),
                    title: "Neon Drift",
                    selected: false,
                    action: {},
                    staticPreview: true
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Theme Preview Card

private struct ThemePreviewCard: View {
    let style: BackgroundStyle
    let title: String
    let selected: Bool
    let action: () -> Void
    var staticPreview: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private func staticized(_ style: BackgroundStyle) -> BackgroundStyle {
        switch style {
        case .staticGradient(let colors):
            return .staticGradient(colors: colors)
        case .animatedGradient(let colors, _):
            return .staticGradient(colors: colors)
        case .blobs(_, let background):
            // Use the background gradient for a static look
            return .staticGradient(colors: background)
        case .particles(_, let background):
            // Use the background gradient for a static look
            return .staticGradient(colors: background)
        case .customGradient(let colors):
            return .customGradient(colors: colors)
        case .adaptiveGradient(let light, let dark):
            let colors = colorScheme == .dark ? dark : light
            return .staticGradient(colors: colors)
        }
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                ThemedBackground(style: staticPreview ? staticized(style) : style)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .padding(6)
                            .opacity(0.55)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(spacing: 6) {
                    Text(title)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(8)
            }
            .frame(height: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Color.accentColor : Color.white.opacity(0.12), lineWidth: selected ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Theme Editor

private struct CustomThemeEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var style: CustomThemeStyle
    @State private var colors: [Color]
    @State private var appearance: AppearanceOption

    let onSave: (CustomTheme) -> Void
    let onDelete: (() -> Void)?

    private let maxColors = 4

    init(initialTheme: CustomTheme?,
         onSave: @escaping (CustomTheme) -> Void,
         onDelete: (() -> Void)? = nil) {
        self.onSave = onSave
        self.onDelete = onDelete

        if let theme = initialTheme {
            _name = State(initialValue: theme.name)
            _style = State(initialValue: theme.style)
            let baseColors = theme.gradientColors
            _colors = State(initialValue: baseColors.isEmpty ? [Color.blue, Color.purple] : baseColors)
            _appearance = State(initialValue: AppearanceOption(theme.preferredColorScheme))
            self.initialTheme = theme
        } else {
            _name = State(initialValue: "")
            _style = State(initialValue: .staticGradient)
            _colors = State(initialValue: [Color(hex: "#3E4C7C") ?? .indigo,
                                           Color(hex: "#1C1F3A") ?? .blue])
            _appearance = State(initialValue: .system)
            self.initialTheme = nil
        }
    }

    private let initialTheme: CustomTheme?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Theme Name", text: $name)
                        .textInputAutocapitalization(.words)

                    Picker("Style", selection: $style) {
                        ForEach(CustomThemeStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }

                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppearanceOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Colors")) {
                    ForEach(colors.indices, id: \.self) { index in
                        HStack {
                            ColorPicker("", selection: Binding(get: {
                                colors[index]
                            }, set: { newValue in
                                if index < colors.count {
                                    colors[index] = newValue
                                }
                            }), supportsOpacity: false)
                            .labelsHidden()

                            if colors.count > 2 {
                                Button(role: .destructive) {
                                    colors.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .padding(.leading, 4)
                            }
                        }
                    }

                    if colors.count < maxColors {
                        Button {
                            colors.append(colors.last ?? .blue)
                        } label: {
                            Label("Add Color", systemImage: "plus.circle")
                        }
                    }
                }

                if let onDelete {
                    Section {
                        Button("Delete Theme", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(initialTheme == nil ? "New Theme" : "Edit Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let hexes = colors.compactMap { $0.toHex() ?? "#3E4C7C" }
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalName = trimmed.isEmpty ? "Untitled Theme" : trimmed
                        let theme = CustomTheme(id: initialTheme?.id ?? UUID(),
                                                name: finalName,
                                                style: style,
                                                colorHexes: hexes,
                                                preferredColorScheme: appearance.colorScheme)
                        onSave(theme)
                        dismiss()
                    }
                    .disabled(colors.count < 2 || colors.allSatisfy { $0.toHex() == nil })
                }
            }
        }
    }

    private enum AppearanceOption: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: return "System"
            case .light:  return "Light"
            case .dark:   return "Dark"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            }
        }

        init(_ scheme: ColorScheme?) {
            switch scheme {
            case .some(.light): self = .light
            case .some(.dark):  self = .dark
            default:            self = .system
            }
        }
    }
}

